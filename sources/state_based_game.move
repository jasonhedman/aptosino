module aptosino::state_based_game {

    use std::signer;
    
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::type_info;

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
    /// * player: the address of the player
    /// * game_address: the address of the game
    /// * _witness: an instance of the game type
    public fun add_player_game<GameType: drop>(player: address, game_address: address, _witness: GameType) 
    acquires GameMapping {
        assert_game_initialized<GameType>();
        assert_player_not_in_game<GameType>(player);
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global_mut<GameMapping<GameType>>(game_struct_address);
        smart_table::add(&mut game_mapping.mapping, player, game_address);
    }

    /// Removes a game address for a given player and game type
    /// * player: the address of the player
    /// * _witness: an instance of the game type
    public fun remove_player_game<GameType: drop>(player: address, _witness: GameType) acquires GameMapping {
        assert_game_initialized<GameType>();
        assert_player_in_game<GameType>(player);
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global_mut<GameMapping<GameType>>(game_struct_address);
        smart_table::remove(&mut game_mapping.mapping, player);
    }
    
    // getters
    
    /// Gets whether a game is initialized for a given game type
    public fun get_is_game_initialized<GameType: drop>(): bool {
        exists<GameMapping<GameType>>(type_info::account_address(&type_info::type_of<GameType>()))
    }
    
    /// Gets whether a player is in a game for a given game type
    /// * player: the address of the player
    public fun get_is_player_in_game<GameType: drop>(player: address): bool acquires GameMapping {
        assert_game_initialized<GameType>();
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global<GameMapping<GameType>>(game_struct_address);
        smart_table::contains(&game_mapping.mapping, player)
    }
    
    /// Returns the address of the game for a given player and game type
    /// * player: the address of the player
    public fun get_player_game_address<GameType: drop>(player: address): address acquires GameMapping {
        assert_game_initialized<GameType>();
        assert_player_in_game<GameType>(player);
        let game_struct_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_mapping = borrow_global<GameMapping<GameType>>(game_struct_address);
        *smart_table::borrow(&game_mapping.mapping, player)
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
