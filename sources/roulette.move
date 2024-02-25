module aptosino::roulette {
    
    use std::signer;
    
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::randomness;

    // constants
    
    /// The seed for the house resource account
    const ACCOUNT_SEED: vector<u8> = b"APTOSINO_COIN_FLIP";
    /// The divisor for the fee in basis points
    const FEE_BPS_DIVISOR: u64 = 10000;
    
    // error codes
    
    /// The signer is not the deployer of the module
    const ESignerNotDeployer: u64 = 101;
    /// The signer is not the admin of the house
    const ESignerNotAdmin: u64 = 102;
    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 103;
    /// The bet amount is less than the minimum bet allowed
    const EBetLessThanMinBet: u64 = 104;
    /// The bet amount exceeds the maximum bet allowed
    const EBetExceedsMaxBet: u64 = 105;
    /// The bet multiplier is less than the minimum multiplier allowed
    const EBetLessThanMinMultiplier: u64 = 106;
    /// The bet multiplier exceeds the maximum multiplier allowed
    const EBetExceedsMaxMultiplier: u64 = 107;
    /// The predicted outcome is greater than the maximum outcome allowed
    const EPredictedOutcomeGreaterThanMaxOutcome: u64 = 108;
    /// The house does not have enough balance to pay the player
    const EHouseInsufficientBalance: u64 = 109;
    /// The signer does not have sufficient balance to deposit the amount
    const EAdminInsufficientBalance: u64 = 110;
    
    // data structures

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
    
    // events
    
    #[event]
    /// Event emitted when the wheel is spun
    struct SpinWheelEvent has drop, store {
        /// The address of the player
        player_address: address,
        /// The amount bet
        bet_amount: u64,
        /// The multiplier of the bet
        multiplier: u64,
        /// The number the player predicted
        predicted_outcome: u64,
        /// The result of the spin
        result: u64,
        /// The payout to the player
        payout: u64,
    }
    
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
    ) acquires House {
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
    
    // game functions
    
    /// Spins the wheel and pays out the winnings to the player
    /// * player: the signer of the player account
    /// * bet_coins: the coins to bet
    /// * multiplier: the multiplier of the bet (the payout is bet * multiplier)
    /// * predicted_outcome: the number the player predicts (must be less than the multiplier)
    public entry fun spin_wheel(
        player: &signer, 
        bet_amount_input: u64,
        multiplier: u64,
        predicted_outcome: u64
    ) acquires House {
        let result = randomness::u64_range(0, multiplier);
        spin_wheel_impl(player, bet_amount_input, multiplier, predicted_outcome, result);
    }
    
    /// Implementation of the spin_wheel function, extracted to allow testing
    /// * player: the signer of the player account
    /// * bet_coins: the coins to bet
    /// * multiplier: the multiplier of the bet (the payout is bet * multiplier)
    /// * predicted_outcome: the number the player predicts (must be less than the multiplier)
    /// * result: the result of the spin
    fun spin_wheel_impl(
        player: &signer,
        bet_amount: u64,
        multiplier: u64,
        predicted_outcome: u64,
        result: u64
    ) acquires House {
        let player_address = signer::address_of(player);
        assert_player_has_enough_balance(player_address, bet_amount);

        let house = borrow_global_mut<House>(get_house_address());

        assert_bet_is_valid(house, bet_amount, multiplier, predicted_outcome);
        assert_house_has_enough_balance(house, bet_amount, multiplier);

        let fee = bet_amount * house.fee_bps / FEE_BPS_DIVISOR;
        house.accrued_fees = house.accrued_fees + fee;
        
        let payout = if (result == predicted_outcome) {
            // player wins, pay out the winnings
            let payout = bet_amount * (multiplier - 1) - fee;
            coin::transfer<AptosCoin>(
                &account::create_signer_with_capability(&house.signer_cap),
                player_address,
                bet_amount * (multiplier - 1) - fee
            );
            payout
        } else {
            // player loses, the house takes the bet
            coin::transfer<AptosCoin>(
                player,
                get_house_address(),
                bet_amount
            );
            0
        };
        
        event::emit(SpinWheelEvent {
            player_address,
            bet_amount,
            multiplier,
            predicted_outcome,
            result,
            payout,
        });
    }
    
    // admin functions
    
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
    
    // getter functions
    
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
    
    // assert statements
    
    /// Asserts that the signer is the deployer of the module
    fun assert_signer_is_deployer(signer: &signer) {
        assert!(signer::address_of(signer) == @aptosino, ESignerNotDeployer);
    }
    
    /// Asserts that the signer is the admin of the house
    fun assert_signer_is_admin(signer: &signer) acquires House {
        assert!(signer::address_of(signer) == get_admin_address(), ESignerNotAdmin);
    }
    
    /// Asserts that the player has enough balance to bet the given amount
    /// * player: the signer of the player account
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }
    
    /// Asserts that the admin has enough balance to deposit the given amount
    /// * admin_address: the address of the admin
    /// * amount: the amount to deposit
    fun assert_admin_has_enough_balance(admin_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(admin_address) >= amount, EAdminInsufficientBalance);
    }
    
    /// Asserts that the bet is valid
    /// * house: a reference to the house resource
    /// * bet_amount: the amount to bet
    /// * multiplier: the multiplier of the bet
    /// * predicted_outcome: the number the player predicts
    fun assert_bet_is_valid(house: &House, bet_amount: u64, multiplier: u64, predicted_outcome: u64) {
        assert!(bet_amount >= house.min_bet, EBetLessThanMinBet);
        assert!(bet_amount <= house.max_bet, EBetExceedsMaxBet);
        assert!(multiplier > 1, EBetLessThanMinMultiplier);
        assert!(multiplier <= house.max_multiplier, EBetExceedsMaxMultiplier);
        assert!(predicted_outcome < multiplier, EPredictedOutcomeGreaterThanMaxOutcome);
    }
    
    /// Asserts that the house has enough balance to pay the player
    /// * bet_amount: the amount to bet
    /// * multiplier: the multiplier of the bet
    fun assert_house_has_enough_balance(house: &House, bet_amount: u64, multiplier: u64) {
        assert!(
            coin::balance<AptosCoin>(get_house_address()) - house.accrued_fees >= bet_amount * (multiplier - 1), 
            EHouseInsufficientBalance
        );
    }
    
    // test functions
    
    #[test_only]
    public fun test_spin_wheel(
        player: &signer, 
        bet_amount: u64,
        multiplier: u64,
        predicted_outcome: u64,
        result: u64
    ) acquires House {
        spin_wheel_impl(player, bet_amount, multiplier, predicted_outcome, result);
    }
}
