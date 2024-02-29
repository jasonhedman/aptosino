module aptosino::dice {
    
    use std::signer;
    
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::randomness;
    
    use aptosino::house;

    // error codes
    
    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 101;
    /// The predicted outcome is 0 or greater than or equal to the maximum outcome
    const EPredictedOutcomeInvalid: u64 = 102;
    
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
        result: u64,
        /// The payout to the player
        payout: u64,
    }
    
    // game functions
    
    /// Rolls the dice and pays out the winnings to the player
    /// * player: the signer of the player account
    /// * bet_coins: the coins to bet
    /// * multiplier: the multiplier of the bet (the payout is bet * multiplier)
    /// * predicted_outcome: the number the player predicts (must be less than the multiplier)
    public entry fun roll_dice(
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
        let player_address = signer::address_of(player);
        assert_player_has_enough_balance(player_address, bet_amount);

        assert_bet_is_valid(max_outcome, predicted_outcome);
        
        let bet_lock = house::acquire_bet_lock(
            player_address, 
            coin::withdraw<AptosCoin>(player, bet_amount),
            max_outcome,
            predicted_outcome
        );
        
        let payout = if (result < predicted_outcome) {
            house::get_max_payout(&bet_lock)
        } else {
            0
        };
        
        house::release_bet_lock(bet_lock, payout);
        
        event::emit(RollDiceEvent {
            player_address,
            bet_amount,
            max_outcome,
            predicted_outcome,
            result,
            payout,
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
            bet_amount * max_outcome / predicted_outcome - house::get_fee_amount(bet_amount)
        } else {
            0
        }
    }
    
    // assert statements
    
    /// Asserts that the player has enough balance to bet the given amount
    /// * player: the signer of the player account
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }
    
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
}
