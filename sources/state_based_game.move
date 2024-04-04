module aptosino::state_based_game {

    use std::signer;
    
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::type_info;
    
    use aptos_framework::object::{Self, DeleteRef, ConstructorRef, Object};
    use aptosino::game;

    use aptosino::game::Game;
    use aptosino::house;

    // errors
    
    /// The caller is not the game creator
    const ECallerNotCreator: u64 = 101;
    /// The game is already initialized
    const EGameAlreadyInitialized: u64 = 102;
    /// The game is not initialized
    const EGameNotInitialized: u64 = 103;
    /// The player is not in a game
    const EPlayerNotInGame: u64 = 104;
    /// The player is already in a game
    const EPlayerAlreadyInGame: u64 = 105;
    
    // structs
    
    /// A game object
    struct GameObject has key {
        /// The game object
        game: Game,
        /// The delete reference for after the game is resolved
        delete_ref: DeleteRef,
    }

    /// A mapping from player address to game object address
    struct GameMapping<phantom GameType: drop> has key {
        /// The mapping from player address to game object address
        mapping: SmartTable<address, address>
    }
    
    /// Initializes a new state-based game for the given game type
    /// * creator: the address of the creator
    /// * _witness: an instance of the game type
    public fun init<GameType: drop>(creator: &signer, _witness: GameType) {
        assert_caller_is_creator<GameType>(creator);
        assert_game_not_initialized<GameType>();
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
        let player_address = signer::address_of(player);
        assert_player_not_in_game<GameType>(player_address);
        
        let game = game::create_game(player, bet_amount, _witness);
        
        let constructor_ref = object::create_object(house::get_house_address());
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        
        let game_mapping = borrow_global_mut<GameMapping<GameType>>(game_struct_address);
        
        move_to(&object::generate_signer(&constructor_ref), GameObject {
            game,
            delete_ref: object::generate_delete_ref(&constructor_ref)
        });
        
        smart_table::add(
            &mut game_mapping.mapping, 
            player_address, 
            object::address_from_constructor_ref(&constructor_ref)
        );
        
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
    ) acquires GameMapping, GameObject {
        assert_game_initialized<GameType>();
        assert_player_in_game<GameType>(player_address);
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global_mut<GameMapping<GameType>>(game_struct_address);
        let game_address = smart_table::remove(&mut game_mapping.mapping, player_address);
        
        let GameObject {
            game,
            delete_ref
        } = move_from<GameObject>(game_address);
        
        game::resolve_game(game, payout_numerator, payout_denominator, witness);
        
        object::delete(delete_ref);
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
        *smart_table::borrow(&game_mapping.mapping, player)
    }
    
    #[view]
    /// Returns the bet amount for a given player and game type
    /// * player: the address of the player
    public fun get_player_bet_amount<GameType: drop>(player: address): u64 acquires GameMapping, GameObject {
        assert_game_initialized<GameType>();
        assert_player_in_game<GameType>(player);
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global<GameMapping<GameType>>(game_struct_address);
        let game_address = *smart_table::borrow(&game_mapping.mapping, player);
        game::get_bet_amount(&borrow_global<GameObject>(game_address).game)
    }
    
    #[view]
    /// Returns the game object for a given player and game type
    /// * player_address: the address of the player
    public fun get_game_object<GameType: drop, Game: key>(player_address: address): Object<Game> acquires GameMapping {
        assert_game_initialized<GameType>();
        assert_player_in_game<GameType>(player_address);
        object::address_to_object<Game>(get_player_game_address<GameType>(player_address))
    }
    
    #[view]
    /// Returns the player address for a given game object
    /// * game_object: the game object
    public fun get_player_address(game_object_address: address): address acquires GameObject {
        let game_object = borrow_global<GameObject>(game_object_address);
        game::get_player_address(&game_object.game)
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
    
}
