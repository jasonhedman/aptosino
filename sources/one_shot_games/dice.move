module aptosino::dice {
    
    use std::signer;
    use aptos_std::math64;

    use aptos_framework::event;
    use aptos_framework::randomness;

    use aptosino::house;
    use aptosino::game;

    // error codes
    
    /// The predicted outcome is 0 or greater than or equal to the maximum outcome
    const EPredictedOutcomeInvalid: u64 = 101;
    
    // game type
    
    struct DiceGame has drop {}
    
    // events
    
    #[event]
    /// Event emitted when the dice are rolled
    struct RollDiceEvent has drop, store {
        /// The address of the player
        player_address: address,
        /// The amount bet
        bet_amount: u64,
        /// The maximum outcome allowed
        max_outcome: u64,
        /// The number the player predicted the roll will be less than
        predicted_outcome: u64,
        /// The result of the spin
        result: u64
    }
    
    // admin functions
    
    /// Approves the dice game on the house module
    /// * admin: the signer of the admin account
    public entry fun approve_game(admin: &signer, fee_bps: u64) {
        house::approve_game<DiceGame>(admin, fee_bps, DiceGame {});
    }
    
    // game functions
    
    /// Rolls the dice and pays out the winnings to the player
    /// * player: the signer of the player account
    /// * bet_coins: the coins to bet
    /// * multiplier: the multiplier of the bet (the payout is bet * multiplier)
    /// * predicted_outcome: the number the player predicts (must be less than the multiplier)
    entry fun roll_dice(
        player: &signer, 
        bet_amount_input: u64,
        max_outcome: u64,
        predicted_outcome: u64
    ) {
        let result = randomness::u64_range(0, max_outcome);
        roll_dice_impl(player, bet_amount_input, max_outcome, predicted_outcome, result);
    }
    
    /// Implementation of the roll_dice function, extracted to allow testing
    /// * player: the signer of the player account
    /// * bet_coins: the coins to bet
    /// * multiplier: the multiplier of the bet (the payout is bet * multiplier)
    /// * predicted_outcome: the number the player predicts (must be less than the multiplier)
    /// * result: the result of the spin
    fun roll_dice_impl(
        player: &signer,
        bet_amount: u64,
        max_outcome: u64,
        predicted_outcome: u64,
        result: u64
    ) {
        assert_bet_is_valid(max_outcome, predicted_outcome);
        
        let game = game::create_game(player, bet_amount, DiceGame {});
        
        let payout_numerator = if (result < predicted_outcome) {
            max_outcome
        } else {
            0
        };
        
        game::resolve_game(game, payout_numerator, predicted_outcome, DiceGame {});
        
        event::emit(RollDiceEvent {
            player_address: signer::address_of(player),
            bet_amount,
            max_outcome,
            predicted_outcome,
            result,
        });
    }
    
    // getters
    
    #[view]
    /// Returns the payout for the given bet
    /// * bet_amount: the amount bet
    /// * max_outcome: the maximum outcome allowed
    /// * predicted_outcome: the number the player predicts the roll will be less than
    public fun get_payout(bet_amount: u64, max_outcome: u64, predicted_outcome: u64): u64 {
        if (predicted_outcome < max_outcome) {
            math64::mul_div(bet_amount, max_outcome, predicted_outcome) - house::get_fee_amount<DiceGame>(bet_amount)
        } else {
            0
        }
    }
    
    // assert statements
    
    /// Asserts that the bet is valid
    /// * max_outcome: the maximum outcome allowed
    /// * predicted_outcome: the number the player predicts the roll will be less than
    fun assert_bet_is_valid(max_outcome: u64, predicted_outcome: u64) {
        assert!(predicted_outcome < max_outcome && predicted_outcome > 0, EPredictedOutcomeInvalid);
    }
    
    // test functions
    
    #[test_only]
    public fun test_roll_dice(
        player: &signer, 
        bet_amount: u64,
        max_outcome: u64,
        predicted_outcome: u64,
        result: u64
    ) {
        roll_dice_impl(player, bet_amount, max_outcome, predicted_outcome, result);
    }
    
    #[test_only]
    public fun test_roll_dice_entry(
        player: &signer, 
        bet_amount: u64,
        max_outcome: u64,
        predicted_outcome: u64
    ) {
        roll_dice(player, bet_amount, max_outcome, predicted_outcome);
    }
}
