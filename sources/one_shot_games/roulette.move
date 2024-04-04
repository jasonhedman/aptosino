module aptosino::roulette {

    use std::signer;
    use std::vector;
    use aptos_std::math64;

    use aptos_framework::event;
    use aptos_framework::randomness;
    use aptosino::game;

    use aptosino::house;

    // constants
    
    const NUM_OUTCOMES: u8 = 36;

    // error codes
    
    /// The number of bets does not match the number of predicted outcomes
    const ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes: u64 = 101;
    /// The number of bets is zero
    const ENumberOfBetsIsZero: u64 = 102;
    /// The bet amount is zero
    const EBetAmountIsZero: u64 = 103;
    /// The number of predicted outcomes is zero for a bet
    const ENumberOfPredictedOutcomesIsZero: u64 = 104;
    /// A predicted outcome is out of range
    const EPredictedOutcomeOutOfRange: u64 = 105;
    
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
    }
    
    // admin functions

    /// Approves the dice game on the house module
    /// * admin: the signer of the admin account
    public entry fun approve_game(admin: &signer, fee_bps: u64) {
        house::approve_game<RouletteGame>(admin, fee_bps, RouletteGame {});
    }

    // game functions

    /// Spins the wheel and pays out the player
    /// * player: the signer of the player account
    /// * bet_amount_inputs: the amount to bet on each predicted outcome
    /// * predicted_outcomes: the numbers the player predicts for each corresponding bet
    entry fun spin_wheel(
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
        vector::for_each(bet_amounts, |amount| {
            total_bet_amount = total_bet_amount + amount;
        });

        let game = game::create_game(player, total_bet_amount, RouletteGame {});
        
        let payout_numerator = 0;
        let payout_denominator = 0;
        
        let i = 0;
        while (i < vector::length(&bet_amounts)) {
            let predicted_outcome = vector::borrow(&predicted_outcomes, i);
            assert_predicted_outcome_is_valid(predicted_outcome);
            if(vector::contains(predicted_outcome, &result)) {
                payout_numerator = payout_numerator + (NUM_OUTCOMES as u64) * *vector::borrow(&bet_amounts, i);
                payout_denominator = payout_denominator + vector::length(predicted_outcome) * total_bet_amount;
            };
            i = i + 1;
        };
        
        game::resolve_game(
            game, 
            payout_numerator, 
            if(payout_denominator > 0) { payout_denominator } else { 1 }, 
            RouletteGame {}
        );
        
        event::emit(SpinWheelEvent {
            player_address: signer::address_of(player),
            bet_amounts,
            predicted_outcomes,
            result,
        });
    }
    
    // getters
    
    #[view]
    /// Returns the payout for a given bet
    /// * bet_amount: the amount to bet
    /// * predicted_outcome: the numbers the player predicts
    public fun get_payout(bet_amount: u64, predicted_outcome: vector<u8>): u64 {
        if(vector::all(&predicted_outcome, |outcome| { *outcome < NUM_OUTCOMES })) {
            math64::mul_div(bet_amount, (NUM_OUTCOMES as u64), vector::length(&predicted_outcome)) 
                - house::get_fee_amount<RouletteGame>(bet_amount)
        } else {
            0
        }
    }

    // assert statements

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
    
    #[test_only]
    public fun test_spin_wheel_entry(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<vector<u8>>,
    ) {
        spin_wheel(player, bet_amounts, predicted_outcomes);
    }
}
