module aptosino::game {

    use std::signer;
    
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{AptosCoin};

    use aptosino::house::{Self, BetLock};
    
    // errors

    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 101;
    
    // admin functions
    
    /// Approves a game to be used by the house
    /// * admin: the signer of the admin account
    /// * witness: the witness of the game to approve
    public fun approve_game<GameType: drop>(admin: &signer, witness: GameType) {
        house::approve_game(admin, witness);
    }
    
    // betting functions
    
    /// Acquires a bet lock for the given game
    /// * player: the signer of the player account
    /// * bet_amount: the amount to bet
    /// * multiplier_numerator: the numerator of the multiplier
    /// * multiplier_denominator: the denominator of the multiplier
    /// * witness: the witness of the game to bet on
    public fun acquire_bet_lock<GameType: drop>(
        player: &signer,
        bet_amount: u64,
        multiplier_numerator: u64,
        multiplier_denominator: u64,
        witness: GameType
    ): BetLock<GameType> {
        let player_address = signer::address_of(player);
        assert_player_has_enough_balance(player_address, bet_amount);
        house::acquire_bet_lock(
            player_address, 
            coin::withdraw(player, bet_amount), 
            multiplier_numerator, 
            multiplier_denominator, 
            witness
        )
    }
    
    /// Releases a bet lock
    /// * bet_lock: the bet lock to release
    /// * payout: the amount to pay to the player
    public fun release_bet_lock<GameType: drop>(bet_lock: BetLock<GameType>, payout: u64) {
        house::release_bet_lock(bet_lock, payout);
    }
    
    // asserts

    /// Asserts that the player has enough balance to bet the given amount
    /// * player: the signer of the player account
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }
    
}
