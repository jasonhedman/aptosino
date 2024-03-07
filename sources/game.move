module aptosino::game {

    use std::signer;

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event;
    
    use aptosino::house;
    
    // errors
    
    /// The game is not approved on the house
    const EGameNotApproved: u64 = 101;
    /// The bet amount is zero
    const EBetAmountIsZero: u64 = 102;
    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 103;
    
    // structs

    /// The game struct
    struct Game has store {
        /// The address of the player
        player_address: address,
        /// coin bet
        bet: Coin<AptosCoin>
    }
    
    // events

    #[event]
    /// emitted when a game is resolved
    struct GameResolved has drop, store {
        /// The address of the player
        player_address: address,
        /// The payout amount
        payout: u64
    }
    
    /// Creates a game struct with the player's bet
    /// * player: the player's signer
    /// * bet_amount: the amount to bet
    /// * _witness: an instance of the GameType struct
    public fun create_game<GameType: drop>(player: &signer, bet_amount: u64, _witness: GameType): Game {
        assert_game_is_approved<GameType>();
        assert_bet_amount_is_greater_than_zero(bet_amount);
        let player_address = signer::address_of(player);
        
        assert_player_has_enough_balance(player_address, bet_amount);
        Game {
            player_address,
            bet: coin::withdraw<AptosCoin>(player, bet_amount)
        }
    }
    
    /// Resolves a game and pays out the player
    /// * game: the game struct
    /// * payout_numerator: the payout numerator
    /// * payout_denominator: the payout denominator
    /// * witness: an instance of the GameType struct
    public fun resolve_game<GameType: drop>(
        game: Game, 
        payout_numerator: u64, 
        payout_denominator: u64, 
        witness: GameType
    ) {
        let Game {
            player_address,
            bet,
        } = game;
        
        let player_balance_before = coin::balance<AptosCoin>(player_address);

        house::pay_out(player_address, bet, payout_numerator, payout_denominator, witness);

        let player_balance_after = coin::balance<AptosCoin>(player_address);
        let payout = if(player_balance_after > player_balance_before) {
            player_balance_after - player_balance_before
        } else {
            0
        };
        
        event::emit(GameResolved {
            player_address,
            payout
        });
    }
    
    // getters
    
    /// Returns the address of the player
    /// * game: the game struct
    public fun get_player_address(game: &Game): address {
        game.player_address
    }
    
    /// Returns the amount bet
    /// * game: the game struct
    public fun get_bet_amount(game: &Game): u64 {
        coin::value(&game.bet)
    }

    // asserts
    
    /// Asserts that the game is approved on the house
    fun assert_game_is_approved<GameType: drop>() {
        assert!(house::is_game_approved<GameType>(), EGameNotApproved);
    }
    
    /// Asserts that the bet amount is greater than zero
    /// * amount: the amount to bet
    fun assert_bet_amount_is_greater_than_zero(amount: u64) {
        assert!(amount > 0, EBetAmountIsZero);
    }

    /// Asserts that the player has enough balance to bet the given amount
    /// * player_address: the address of the player
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }
}
