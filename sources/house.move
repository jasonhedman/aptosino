/// This module implements the house resource which manages the betting parameters
module aptosino::house {

    use std::option;
    use std::signer;
    use std::string;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability, FreezeCapability};
    
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
    /// The signer does not have sufficient balance
    const EInsufficientBalance: u64 = 103;
    /// The amount to deposit or withdraw is invalid
    const EAmountInvalid: u64 = 104;
    /// The game is not approved by the house
    const EGameNotApproved: u64 = 105;
    /// The game is already approved by the house
    const EGameAlreadyApproved: u64 = 106;
    /// The house does not have enough balance to pay the player
    const EHouseInsufficientBalance: u64 = 107;
    /// The bet amount is less than the minimum bet allowed
    const EBetLessThanMinBet: u64 = 108;
    /// The bet amount exceeds the maximum bet allowed
    const EBetExceedsMaxBet: u64 = 109;
    /// The bet multiplier exceeds the maximum multiplier allowed
    const EBetExceedsMaxMultiplier: u64 = 110;

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
        /// The mint capability for house shares coin
        mint_cap: MintCapability<HouseShares>,
        /// The burn capability for house shares coin
        burn_cap: BurnCapability<HouseShares>,
        /// The freeze capability for house shares coin
        freeze_cap: FreezeCapability<HouseShares>,
    }
    
    /// A game approved by the house
    struct ApprovedGame<phantom GameType: drop> has key {}
    
    /// A struct representing a share of the house
    struct HouseShares has drop {}
    
    // initialization

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
        
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<HouseShares>(
            deployer,
            string::utf8(b"House Stake"),
            string::utf8(b"STAKE"),
            8,
            true
        );

        move_to(&resourse_acc, House {
            admin_address: signer::address_of(deployer),
            signer_cap,
            min_bet,
            max_bet,
            max_multiplier,
            fee_bps,
            mint_cap,
            burn_cap,
            freeze_cap
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
        assert_house_has_enough_balance(bet_amount, payout_numerator, payout_denominator);
        
        let fee = bet_amount * house.fee_bps / FEE_BPS_DIVISOR;
        
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
    
    // house shares functions

    /// Adds coins to the house resource account
    /// * signer: the signer of the admin account
    /// * amount: the amount of coins to add
    public entry fun deposit(signer: &signer, amount: u64) acquires House {
        assert_coin_amount_valid(amount);
        let player_address = signer::address_of(signer);
        assert_signer_has_sufficient_balance<AptosCoin>(player_address, amount);
        if(!coin::is_account_registered<HouseShares>(player_address)) {
            coin::register<HouseShares>(signer);
        };
        coin::deposit(player_address, coin::mint(
            get_house_shares_amount_from_deposit_amount(amount),
            &borrow_global<House>(get_house_address()).mint_cap
        ));
        coin::transfer<AptosCoin>(signer, get_house_address(), amount);
    }

    /// Withdraws the accrued fees from the house resource account
    /// * signer: the signer of the admin account
    public entry fun withdraw(signer: &signer, shares_amount: u64) acquires House {
        assert_coin_amount_valid(shares_amount);
        let signer_address = signer::address_of(signer);
        assert_signer_has_sufficient_balance<HouseShares>(signer_address, shares_amount);
        let house = borrow_global<House>(get_house_address());
        let house_signer = account::create_signer_with_capability(&house.signer_cap);
        coin::transfer<AptosCoin>(
            &house_signer,
            signer_address,
            get_withdraw_amount_from_shares_amount(shares_amount)
        );
        coin::burn(
            coin::withdraw<HouseShares>(signer, shares_amount),
            &house.burn_cap
        );
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
    /// Returns the fee in basis points
    public fun get_house_balance(): u64 {
        coin::balance<AptosCoin>(get_house_address())
    }
    
    #[view]
    /// Returns the number of house shares that have been minted
    public fun get_house_shares_supply(): u64 {
        (*option::borrow(&coin::supply<HouseShares>()) as u64)
    }
    
    #[view]
    /// Retusn the amount of house shares to issue for a given deposit amount
    /// deposit_amount: the amount of coins to deposit
    public fun get_house_shares_amount_from_deposit_amount(deposit_amount: u64): u64 {
        let house_balance = get_house_balance();
        if(house_balance == 0) {
            deposit_amount
        } else {
            deposit_amount * get_house_shares_supply() / house_balance
        }
    }

    #[view]
    /// Retusn the amount of coins to return for burning an amoun of house shares
    /// withdraw shares_amount: the amount of house shares to burn
    public fun get_withdraw_amount_from_shares_amount(shares_amount: u64): u64 {
        let shares_supply = get_house_shares_supply();
        if(shares_supply == 0 || shares_amount > shares_supply) {
            0
        } else {
            shares_amount * get_house_balance() / shares_supply
        }
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
    fun assert_signer_has_sufficient_balance<CoinType>(admin_address: address, amount: u64) {
        assert!(coin::balance<CoinType>(admin_address) >= amount, EInsufficientBalance);
    }
    
    /// Asserts that the deposit or withdraw amount is greater than zero
    /// * amount: the amount of coins to deposit or withdraw
    fun assert_coin_amount_valid(amount: u64) {
        assert!(amount > 0, EAmountInvalid);
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
        bet_amount: u64, 
        multiplier_numerator: u64, 
        multiplier_denominator: u64
    ) {
        assert!(
            coin::balance<AptosCoin>(get_house_address()) >= bet_amount * multiplier_numerator / multiplier_denominator,
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
