module aptosino::roulette {

    use std::signer;
    use std::vector;

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
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

    // events

    #[event]
    /// Event emitted when the dice are rolled
    struct SpinWheelAddress has drop, store {
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

    // game functions

    /// Rolls the dice and pays out the winnings to the player
    /// * player: the signer of the player account
    /// * bet_amount_inputs: the amounts to bet on each predicted outcome
    /// * predicted_outcomes: the numbers the player predicts for each bet
    public entry fun spin_wheel(
        player: &signer,
        bet_amount_inputs: vector<u64>,
        predicted_outcomes: vector<vector<u8>>,
    ) {
        let result = randomness::u8_range(0, NUM_OUTCOMES);
        spin_wheel_impl(player, bet_amount_inputs, predicted_outcomes, result);
    }

    /// Implementation of the roll_dice function, extracted to allow testing
    /// * player: the signer of the player account
    /// * bet_amounts: the amount to bet
    /// * predicted_outcomes: the number the player predicts
    /// * result: the result of the spin
    fun spin_wheel_impl(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<vector<u8>>,
        result: u8
    ) {
        let player_address = signer::address_of(player);
        let total_bet_amount = 0;
        vector::for_each(bet_amounts, |bet_amount| { total_bet_amount = total_bet_amount + bet_amount; });
        assert_player_has_enough_balance(player_address, total_bet_amount);

        assert_bets_are_valid(&bet_amounts, &predicted_outcomes);
        
        let total_payout = 0;
        
        let i = 0;
        // the length of bet_amounts and predicted_outcomes is already checked to be equal
        while(i < vector::length(&bet_amounts)) {
            let outcomes = vector::borrow(&predicted_outcomes, i);
            assert_predicted_outcome_is_valid(outcomes);
            let bet_lock = house::acquire_bet_lock(
                player_address,
                coin::withdraw<AptosCoin>(player, *vector::borrow(&bet_amounts, i)),
                (NUM_OUTCOMES as u64),
                vector::length(outcomes)
            );
            let payout = if(vector::any(outcomes, |outcome| { *outcome == result })) {
                house::get_max_payout(&bet_lock)
            } else {
                0
            };
            total_payout = total_payout + payout;
            house::release_bet_lock(bet_lock, payout);
            i = i + 1;
        };

        event::emit(SpinWheelAddress {
            player_address,
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
        bet_amount * (NUM_OUTCOMES as u64) / vector::length(&predicted_outcome) - house::get_fee_amount(bet_amount)
    }

    // assert statements

    /// Asserts that the player has enough balance to bet the given amount
    /// * player: the signer of the player account
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }

    /// Asserts that the bets are valid
    /// * multiplier: the multiplier of the bet
    /// * bet_amounts: the amounts the player bets
    /// * predicted_outcome: the numbers the player predicts for each bet
    fun assert_bets_are_valid(bet_amounts: &vector<u64>, predicted_outcomes: &vector<vector<u8>>) {
        assert!(vector::length(bet_amounts) == vector::length(predicted_outcomes), 
            ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes);
        assert!(vector::length(bet_amounts) > 0, ENumberOfBetsIsZero);
        assert!(vector::all(bet_amounts, |amount| { *amount > 0 }), EBetAmountIsZero);
    }
    
    /// Asserts that a predicted outcome is valid
    /// * predicted_outcome: the numbers the player predicts for each bet
    fun assert_predicted_outcome_is_valid(predicted_outcome: &vector<u8>) {
        assert!(vector::length(predicted_outcome) > 0, ENumberOfPredictedOutcomesIsZero);
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
