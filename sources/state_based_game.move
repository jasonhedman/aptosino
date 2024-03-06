module aptosino::state_based_game {

    use std::signer;
    
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::type_info;
    
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event;
    use aptos_framework::object::{Self, DeleteRef, ConstructorRef};
    
    use aptosino::house;

    // errors
    
    /// The caller is not the game creator
    const ECallerNotCreator: u64 = 101;
    /// The game is already initialized
    const EGameAlreadyInitialized: u64 = 102;
    /// The game is not initialized
    const EGameNotInitialized: u64 = 103;
    /// The game is not approved on the house
    const EGameNotApproved: u64 = 104;
    /// The player is not in a game
    const EPlayerNotInGame: u64 = 105;
    /// The player is already in a game
    const EPlayerAlreadyInGame: u64 = 106;
    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 107;
    
    // structs
    
    /// A game object
    struct Game has store {
        /// The address of the game
        game_address: address,
        /// The bet
        bet: Coin<AptosCoin>,
        /// The delete reference for after the game is resolved
        delete_ref: DeleteRef,
    }

    /// A mapping from player address to game object address
    struct GameMapping<phantom GameType: drop> has key {
        /// The mapping from player address to game object address
        mapping: SmartTable<address, Game>
    }
    
    // events
    
    #[event]
    /// emitted when a game is resolved
    struct GameResolved has drop, store {
        /// The address of the player
        player_address: address,
        /// The address of the game
        game_address: address,
        /// The payout amount
        payout: u64
    }
    
    /// Initializes a new state-based game for the given game type
    /// * creator: the address of the creator
    /// * _witness: an instance of the game type
    public fun init<GameType: drop>(creator: &signer, _witness: GameType) {
        assert_caller_is_creator<GameType>(creator);
        assert_game_not_initialized<GameType>();
        assert_game_is_approved<GameType>();
        move_to(creator, GameMapping<GameType> {
            mapping: smart_table::new()
        })
    }
    
    // mutators
    
    /// Adds a game address for a given player and game type
    /// * player: the player signer
    /// * game_address: the address of the game
    /// * bet_amount: the bet amount
    /// * constructor_ref: the constructor reference for the game
    /// * _witness: an instance of the game type
    public fun create_game<GameType: drop>(
        player: &signer, 
        bet_amount: u64,
        _witness: GameType
    ): ConstructorRef
    acquires GameMapping {
        assert_game_initialized<GameType>();
        assert_game_is_approved<GameType>();
        let player_address = signer::address_of(player);
        assert_player_not_in_game<GameType>(player_address);
        assert_player_has_enough_balance(player_address, bet_amount);
        
        let constructor_ref = object::create_object(house::get_house_address());
        
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global_mut<GameMapping<GameType>>(game_struct_address);
        smart_table::add(&mut game_mapping.mapping, player_address, Game {
            game_address: object::address_from_constructor_ref(&constructor_ref),
            bet: coin::withdraw(player, bet_amount),
            delete_ref: object::generate_delete_ref(&constructor_ref)
        });
        
        constructor_ref
    }

    /// Removes a game address for a given player and game type
    /// * player_address: the address of the player
    /// * payout_numerator: the payout numerator
    /// * payout_denominator: the payout denominator
    /// * _witness: an instance of the game type
    public fun resolve_game<GameType: drop>(
        player_address: address, 
        payout_numerator: u64,
        payout_denominator: u64,
        witness: GameType
    ) acquires GameMapping {
        assert_game_initialized<GameType>();
        assert_player_in_game<GameType>(player_address);
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global_mut<GameMapping<GameType>>(game_struct_address);
        let Game { 
            game_address, 
            bet,
            delete_ref
        } = smart_table::remove(&mut game_mapping.mapping, player_address);
        
        let player_balance_before = coin::balance<AptosCoin>(player_address);
        
        house::pay_out(player_address, bet, payout_numerator, payout_denominator, witness);
        
        let player_balance_after = coin::balance<AptosCoin>(player_address);
        let payout = if(player_balance_after > player_balance_before) {
            player_balance_after - player_balance_before
        } else {
            0
        };
        
        object::delete(delete_ref);
        
        event::emit(GameResolved {
            player_address,
            game_address,
            payout
        });
    }
    
    // getters
    
    #[view]
    /// Gets whether a game is initialized for a given game type
    public fun get_is_game_initialized<GameType: drop>(): bool {
        exists<GameMapping<GameType>>(type_info::account_address(&type_info::type_of<GameType>()))
    }
    
    #[view]
    /// Gets whether a player is in a game for a given game type
    /// * player: the address of the player
    public fun get_is_player_in_game<GameType: drop>(player: address): bool acquires GameMapping {
        assert_game_initialized<GameType>();
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global<GameMapping<GameType>>(game_struct_address);
        smart_table::contains(&game_mapping.mapping, player)
    }
    
    #[view]
    /// Returns the address of the game for a given player and game type
    /// * player: the address of the player
    public fun get_player_game_address<GameType: drop>(player: address): address acquires GameMapping {
        assert_game_initialized<GameType>();
        assert_player_in_game<GameType>(player);
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global<GameMapping<GameType>>(game_struct_address);
        smart_table::borrow(&game_mapping.mapping, player).game_address
    }
    
    #[view]
    /// Returns the bet amount for a given player and game type
    /// * player: the address of the player
    public fun get_player_bet_amount<GameType: drop>(player: address): u64 acquires GameMapping {
        assert_game_initialized<GameType>();
        assert_player_in_game<GameType>(player);
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global<GameMapping<GameType>>(game_struct_address);
        coin::value(&smart_table::borrow(&game_mapping.mapping, player).bet)
    }
    
    // asserts
    
    /// Asserts that the caller is the creator of the game
    /// * creator: the address of the creator
    fun assert_caller_is_creator<GameType: drop>(creator: &signer) {
        assert!(signer::address_of(creator) == 
            type_info::account_address(&type_info::type_of<GameType>()), ECallerNotCreator);
    }
    
    /// Asserts that the game has been initialized
    fun assert_game_initialized<GameType: drop>() {
        assert!(get_is_game_initialized<GameType>(), EGameNotInitialized);
    }
    
    /// Asserts that the game has not been initialized
    fun assert_game_not_initialized<GameType: drop>() {
        assert!(!get_is_game_initialized<GameType>(), EGameAlreadyInitialized);
    }
    
    /// Asserts that the game is approved on the house
    fun assert_game_is_approved<GameType: drop>() {
        assert!(house::is_game_approved<GameType>(), EGameNotApproved);
    }
    
    /// Asserts that the player is in a game
    /// * player: the address of the player
    fun assert_player_in_game<GameType: drop>(player: address) acquires GameMapping {
        assert!(get_is_player_in_game<GameType>(player), EPlayerNotInGame);
    }
    
    /// Asserts that the player is not in a game
    /// * player: the address of the player
    fun assert_player_not_in_game<GameType: drop>(player: address) acquires GameMapping {
        assert!(!get_is_player_in_game<GameType>(player), EPlayerAlreadyInGame);
    }

    /// Asserts that the player has enough balance to bet the given amount
    /// * player_address: the address of the player
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }
}
