/// This module implements the house resource which manages the betting parameters
module aptosino::house {

    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    
    friend aptosino::game;

    // constants

    /// The seed for the house resource account
    const ACCOUNT_SEED: vector<u8> = b"APTOSINO";
    /// The divisor for the fee in basis points
    const FEE_BPS_DIVISOR: u64 = 10000;
    
    // error codes

    /// The signer is not the deployer of the module
    const ESignerNotDeployer: u64 = 101;
    /// The signer is not the admin of the house
    const ESignerNotAdmin: u64 = 102;
    /// The signer does not have sufficient balance to deposit the amount
    const EAdminInsufficientBalance: u64 = 103;
    /// The game is not approved by the house
    const EGameNotApproved: u64 = 104;
    /// The game is already approved by the house
    const EGameAlreadyApproved: u64 = 105;
    /// The house does not have enough balance to pay the player
    const EHouseInsufficientBalance: u64 = 106;
    /// The bet amount is less than the minimum bet allowed
    const EBetLessThanMinBet: u64 = 107;
    /// The bet amount exceeds the maximum bet allowed
    const EBetExceedsMaxBet: u64 = 108;
    /// The bet multiplier exceeds the maximum multiplier allowed
    const EBetExceedsMaxMultiplier: u64 = 109;

    /// Data stored on the house resource account
    struct House has key {
        /// The address of the admin of the house; the admin can withdraw the accrued fees and set the parameters of the house
        admin_address: address,
        /// The signer capability of the house, used to withdraw the accrued fees and pay out winnings
        signer_cap: SignerCapability,
        /// The minimum bet allowed
        min_bet: u64,
        /// The maximum bet allowed
        max_bet: u64,
        /// The maximum multiplier allowed
        max_multiplier: u64,
        /// The fee in basis points
        fee_bps: u64,
        /// The amount of accrued fees; the admin can withdraw this amount and reset it to 0
        accrued_fees: u64,
    }
    
    /// A game approved by the house
    struct ApprovedGame<phantom GameType: drop> has key {}

    /// Initializes the house with the given parameters and deposits the given coins into the house resource account
    /// * deployer: the signer of the account that deployed the module
    /// * initial_coins: the coins to deposit into the house resource account
    /// * min_bet: the minimum bet allowed
    /// * max_bet: the maximum bet allowed
    /// * max_multiplier: the maximum multiplier allowed
    /// * fee_bps: the fee in basis points
    public entry fun init(
        deployer: &signer,
        initial_coins: u64,
        min_bet: u64,
        max_bet: u64,
        max_multiplier: u64,
        fee_bps: u64
    ) 
    acquires House {
        assert_signer_is_deployer(deployer);

        let (resourse_acc, signer_cap) = account::create_resource_account(deployer, ACCOUNT_SEED);

        coin::register<AptosCoin>(&resourse_acc);

        move_to(&resourse_acc, House {
            admin_address: signer::address_of(deployer),
            signer_cap,
            min_bet,
            max_bet,
            max_multiplier,
            fee_bps,
            accrued_fees: 0,
        });

        deposit(deployer, initial_coins);
    }
    
    // betting functions
    
    /// Pays out a bet to the bettor
    /// * bettor: the address of the bettor
    /// * bet: the coins to bet
    /// * payout_numerator: the numerator of the payout
    /// * payout_denominator: the denominator of the payout
    /// * _witness: an instance of the GameType struct, enforces that the call is made from the correct game module
    public(friend) fun pay_out<GameType: drop>(
        bettor: address,
        bet: Coin<AptosCoin>,
        payout_numerator: u64,
        payout_denominator: u64,
        _witness: GameType
    )
    acquires House {
        assert_game_is_approved<GameType>();
        
        let house = borrow_global_mut<House>(get_house_address());
        
        let bet_amount = coin::value(&bet);
        assert_bet_is_valid(house, bet_amount);
        assert_payout_is_valid(house, payout_numerator, payout_denominator);
        
        coin::deposit(get_house_address(), bet);
        assert_house_has_enough_balance(house, bet_amount, payout_numerator, payout_denominator);
        
        let fee = bet_amount * house.fee_bps / FEE_BPS_DIVISOR;
        house.accrued_fees = house.accrued_fees + fee;
        
        if(payout_numerator > 0) {
            let payout = bet_amount * payout_numerator / payout_denominator - fee;
            coin::deposit(
                bettor, 
                coin::withdraw<AptosCoin>(&account::create_signer_with_capability(&house.signer_cap), payout)
            );
        }
    }

    // admin functions

    /// Approves a game to access the house
    /// * signer: the signer of the admin account
    /// * _witness: an instance of the GameType struct, enforces that the call is made from the correct game module
    public fun approve_game<GameType: drop>(signer: &signer, _witness: GameType) acquires House {
        assert_signer_is_admin(signer);
        assert_game_is_not_approved<GameType>();
        let house = borrow_global<House>(get_house_address());
        move_to(&account::create_signer_with_capability(&house.signer_cap), ApprovedGame<GameType> {});
    }
    
    /// Revokes the approval of a game
    /// * signer: the signer of the admin account
    public entry fun revoke_game<GameType: drop>(signer: &signer) acquires House, ApprovedGame {
        assert_signer_is_admin(signer);
        assert_game_is_approved<GameType>();
        let ApprovedGame<GameType> {} = move_from<ApprovedGame<GameType>>(get_house_address());
    }

    /// Withdraws the accrued fees from the house resource account
    /// * signer: the signer of the admin account
    public entry fun withdraw_fees(signer: &signer) acquires House {
        assert_signer_is_admin(signer);

        let house = borrow_global_mut<House>(get_house_address());
        let house_signer = account::create_signer_with_capability(&house.signer_cap);
        let accrued_fees = house.accrued_fees;
        coin::deposit(
            signer::address_of(signer),
            coin::withdraw<AptosCoin>(&house_signer, accrued_fees)
        );
        house.accrued_fees = 0;
    }

    /// Adds coins to the house resource account
    /// * signer: the signer of the admin account
    /// * amount: the amount of coins to add
    public entry fun deposit(signer: &signer, amount: u64) acquires House {
        assert_signer_is_admin(signer);
        assert_admin_has_enough_balance(signer::address_of(signer), amount);
        coin::transfer<AptosCoin>(signer, get_house_address(), amount);
    }

    /// Sets the admin of the house
    /// * signer: the signer of the deployer account
    /// * admin: the address of the new admin
    public entry fun set_admin(signer: &signer, admin: address) acquires House {
        assert_signer_is_deployer(signer);
        borrow_global_mut<House>(get_house_address()).admin_address = admin;
    }

    /// Sets the minimum bet allowed
    /// * signer: the signer of the admin account
    /// * min_bet: the minimum bet allowed
    public entry fun set_min_bet(signer: &signer, min_bet: u64) acquires House {
        assert_signer_is_admin(signer);
        borrow_global_mut<House>(get_house_address()).min_bet = min_bet;
    }

    /// Sets the maximum bet allowed
    /// * signer: the signer of the admin account
    /// * max_bet: the maximum bet allowed
    public entry fun set_max_bet(signer: &signer, max_bet: u64) acquires House {
        assert_signer_is_admin(signer);
        borrow_global_mut<House>(get_house_address()).max_bet = max_bet;
    }

    /// Sets the fee in basis points
    /// * signer: the signer of the admin account
    /// * fee_bps: the fee in basis points
    public entry fun set_fee_bps(signer: &signer, fee_bps: u64) acquires House {
        assert_signer_is_admin(signer);
        borrow_global_mut<House>(get_house_address()).fee_bps = fee_bps;
    }

    /// Sets the maximum multiplier allowed
    /// * signer: the signer of the admin account
    /// * max_multiplier: the maximum multiplier allowed
    public entry fun set_max_multiplier(signer: &signer, max_multiplier: u64) acquires House {
        assert_signer_is_admin(signer);
        borrow_global_mut<House>(get_house_address()).max_multiplier = max_multiplier;
    }
    
    // view functions

    #[view]
    /// Returns the address of the house resource account
    public fun get_house_address(): address {
        account::create_resource_address(&@aptosino, ACCOUNT_SEED)
    }

    #[view]
    /// Returns the address of the admin of the house
    public fun get_admin_address(): address acquires House {
        borrow_global<House>(get_house_address()).admin_address
    }

    #[view]
    /// Returns the signer capability of the house
    public fun get_min_bet(): u64 acquires House {
        borrow_global<House>(get_house_address()).min_bet
    }

    #[view]
    /// Returns the minimum bet allowed
    public fun get_max_bet(): u64 acquires House {
        borrow_global<House>(get_house_address()).max_bet
    }

    #[view]
    /// Returns the maximum multiplier allowed
    public fun get_max_multiplier(): u64 acquires House {
        borrow_global<House>(get_house_address()).max_multiplier
    }

    #[view]
    /// Returns the maximum bet allowed
    public fun get_fee_bps(): u64 acquires House {
        borrow_global<House>(get_house_address()).fee_bps
    }

    #[view]
    /// Returns the accrued fees
    public fun get_accrued_fees(): u64 acquires House {
        borrow_global<House>(get_house_address()).accrued_fees
    }

    #[view]
    /// Returns the fee in basis points
    public fun get_house_balance(): u64 {
        coin::balance<AptosCoin>(get_house_address())
    }
    
    #[view]
    /// Returns the fee amount on a bet
    /// * bet_amount: the amount of the bet
    public fun get_fee_amount(bet_amount: u64): u64 acquires House {
        let house = borrow_global<House>(get_house_address());
        bet_amount * house.fee_bps / FEE_BPS_DIVISOR
    }
    
    #[view]
    /// Returns whether or not a game is approved by the house
    public fun is_game_approved<GameType: drop>(): bool {
        exists<ApprovedGame<GameType>>(get_house_address())
    }
    
    // assertions

    /// Asserts that the signer is the deployer of the module
    fun assert_signer_is_deployer(signer: &signer) {
        assert!(signer::address_of(signer) == @aptosino, ESignerNotDeployer);
    }

    /// Asserts that the signer is the admin of the house
    fun assert_signer_is_admin(signer: &signer) acquires House {
        assert!(signer::address_of(signer) == get_admin_address(), ESignerNotAdmin);
    }

    /// Asserts that the admin has enough balance to deposit the given amount
    /// * admin_address: the address of the admin
    /// * amount: the amount to deposit
    fun assert_admin_has_enough_balance(admin_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(admin_address) >= amount, EAdminInsufficientBalance);
    }
    
    /// Asserts that the game is approved by the house
    fun assert_game_is_approved<GameType: drop>() {
        assert!(is_game_approved<GameType>(), EGameNotApproved);
    }
    
    /// Asserts that the game is not approved by the house
    fun assert_game_is_not_approved<GameType: drop>() {
        assert!(!is_game_approved<GameType>(), EGameAlreadyApproved);
    }

    /// Asserts that the house has enough balance to pay the player
    /// * bet_amount: the amount to bet
    /// * multiplier: the multiplier of the bet
    fun assert_house_has_enough_balance(
        house: &House, bet_amount: u64, 
        multiplier_numerator: u64, 
        multiplier_denominator: u64
    ) {
        assert!(
            coin::balance<AptosCoin>(get_house_address())
                - house.accrued_fees >= bet_amount * multiplier_numerator / multiplier_denominator,
            EHouseInsufficientBalance
        );
    }

    /// Asserts that the bet is valid
    /// * house: a reference to the house resource
    /// * bet_amount: the amount to bet
    /// * multiplier: the multiplier of the bet
    /// * multiplier_denominator: the denominator of the multiplier
    fun assert_bet_is_valid(house: &House, bet_amount: u64) {
        assert!(bet_amount >= house.min_bet, EBetLessThanMinBet);
        assert!(bet_amount <= house.max_bet, EBetExceedsMaxBet);
        
    }
    
    /// Asserts that the payout is valid
    /// bet_lock: the bet lock
    /// payout: the payout
    fun assert_payout_is_valid(house: &House, payout_numerator: u64, payout_denominator: u64) {
        assert!(payout_numerator <= house.max_multiplier * payout_denominator, EBetExceedsMaxMultiplier);
    }
    
    #[test_only]
    public fun test_pay_out<GameType: drop>(
        bettor: address,
        bet: Coin<AptosCoin>,
        payout_numerator: u64,
        payout_denominator: u64,
        _witness: GameType
    ) acquires House {
        pay_out(bettor, bet, payout_numerator, payout_denominator, _witness);
    }
}
