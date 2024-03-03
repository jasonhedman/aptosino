module aptosino::roulette {

    use std::signer;
    use std::vector;

    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event;
    use aptos_framework::randomness;

    use aptosino::house;

    // constants
    
    const NUM_OUTCOMES: u8 = 36;

    // error codes

    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 101;
    /// The number of bets does not match the number of predicted outcomes
    const ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes: u64 = 102;
    /// The number of bets is zero
    const ENumberOfBetsIsZero: u64 = 103;
    /// The bet amount is zero
    const EBetAmountIsZero: u64 = 104;
    /// The number of predicted outcomes is zero for a bet
    const ENumberOfPredictedOutcomesIsZero: u64 = 105;
    /// A predicted outcome is out of range
    const EPredictedOutcomeOutOfRange: u64 = 106;
    
    // game type
    
    struct RouletteGame has drop {}

    // events

    #[event]
    /// Event emitted when the player spins the wheel
    struct SpinWheelEvent has drop, store {
        /// The address of the player
        player_address: address,
        /// The amount of each bet
        bet_amounts: vector<u64>,
        /// The numbers the player predicts for each bet
        predicted_outcomes: vector<vector<u8>>,
        /// The result of the spin
        result: u8,
        /// The payout to the player
        payout: u64,
    }
    
    // admin functions

    /// Approves the dice game on the house module
    /// * admin: the signer of the admin account
    public entry fun approve_game(admin: &signer) {
        house::approve_game<RouletteGame>(admin, RouletteGame {});
    }

    // game functions

    /// Spins the wheel and pays out the player
    /// * player: the signer of the player account
    /// * bet_amount_inputs: the amount to bet on each predicted outcome
    /// * predicted_outcomes: the numbers the player predicts for each corresponding bet
    public entry fun spin_wheel(
        player: &signer,
        bet_amount_inputs: vector<u64>,
        predicted_outcomes: vector<vector<u8>>,
    ) {
        let result = randomness::u8_range(0, NUM_OUTCOMES);
        spin_wheel_impl(player, bet_amount_inputs, predicted_outcomes, result);
    }

    /// Implementation of the spin_wheel function, extracted to allow testing
    /// * player: the signer of the player account
    /// * bet_amounts: the amount to bet on each predicted outcome
    /// * predicted_outcomes: the numbers the player predicts for each corresponding bet
    /// * result: the result of the spin
    fun spin_wheel_impl(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<vector<u8>>,
        result: u8
    ) {
        
        assert_bets_are_valid(&bet_amounts, &predicted_outcomes);

        let total_bet_amount = 0;
        let total_slot_predictions = 0;
        let i = 0;
        while (i < vector::length(&bet_amounts)) {
            let outcomes = vector::borrow(&predicted_outcomes, i);
            assert_predicted_outcome_is_valid(outcomes);
            total_slot_predictions = total_slot_predictions + vector::length(outcomes);

            total_bet_amount = total_bet_amount + *vector::borrow(&bet_amounts, i);
            
            i = i + 1;
        };

        let player_address = signer::address_of(player);
        assert_player_has_enough_balance(player_address, total_bet_amount);

        let bet_lock = house::acquire_bet_lock(
            player_address,
            coin::withdraw(player, total_bet_amount),
            (NUM_OUTCOMES as u64) * vector::length(&bet_amounts),
            total_slot_predictions,
            RouletteGame {}
        );
        
        let total_payout = 0;
        i = 0;
        while(i < vector::length(&bet_amounts)) {
            let outcomes = vector::borrow(&predicted_outcomes, i);
            let payout = if(vector::any(outcomes, |outcome| { *outcome == result })) {
                get_payout(*vector::borrow(&bet_amounts, i), *outcomes)
            } else {
                0
            };
            total_payout = total_payout + payout;
            i = i + 1;
        };

        house::release_bet_lock(bet_lock, total_payout);

        event::emit(SpinWheelEvent {
            player_address: signer::address_of(player),
            bet_amounts,
            predicted_outcomes,
            result,
            payout: total_payout,
        });
    }
    
    // getters
    
    #[view]
    /// Returns the payout for a given bet
    /// * bet_amount: the amount to bet
    /// * predicted_outcome: the numbers the player predicts
    public fun get_payout(bet_amount: u64, predicted_outcome: vector<u8>): u64 {
        if(vector::all(&predicted_outcome, |outcome| { *outcome < NUM_OUTCOMES })) {
            bet_amount * (NUM_OUTCOMES as u64) / vector::length(&predicted_outcome) - house::get_fee_amount(bet_amount)
        } else {
            0
        }
    }

    // assert statements

    /// Asserts that the player has enough balance to bet the given amount
    /// * player_address: the address of the player
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }

    /// Asserts that the number of bets and predicted outcomes are equal in length, non-empty, and non-zero
    /// * multiplier: the multiplier of the bet
    /// * bet_amounts: the amounts the player bets
    /// * predicted_outcome: the numbers the player predicts for each bet
    fun assert_bets_are_valid(bet_amounts: &vector<u64>, predicted_outcomes: &vector<vector<u8>>) {
        assert!(vector::length(bet_amounts) == vector::length(predicted_outcomes), 
            ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes);
        assert!(vector::length(bet_amounts) > 0, ENumberOfBetsIsZero);
        assert!(vector::all(predicted_outcomes, |outcomes| { vector::length(outcomes) > 0 }), 
            ENumberOfPredictedOutcomesIsZero);
        assert!(vector::all(bet_amounts, |amount| { *amount > 0 }), EBetAmountIsZero);
    }
    
    /// Asserts that each outcome in a vector of predicted outcomes is within the range of possible outcomes
    /// * predicted_outcome: the numbers the player predicts for each bet
    fun assert_predicted_outcome_is_valid(predicted_outcome: &vector<u8>) {
        vector::for_each(*predicted_outcome, |outcome| {
            assert!(outcome < NUM_OUTCOMES, EPredictedOutcomeOutOfRange);
        });
    }

    // test functions

    #[test_only]
    public fun test_spin_wheel(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<vector<u8>>,
        result: u8
    ) {
        spin_wheel_impl(player, bet_amounts, predicted_outcomes, result);
    }
}
