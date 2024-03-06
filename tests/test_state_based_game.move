#[test_only]
module aptosino::test_state_based_game {
    
    use aptosino::state_based_game;
    
    struct TestGame has drop {}
    
    const GAME_ADDRESS: address = @0x101;
    const PLAYER_ADDRESS: address = @0x102;
    
    #[test(aptosino=@aptosino)]
    fun test_init(aptosino: &signer) {
        state_based_game::init(aptosino, TestGame {});
        assert!(state_based_game::get_is_game_initialized<TestGame>(), 0);
    }

    #[test(aptosino=@0x101)]
    #[expected_failure(abort_code=state_based_game::ECallerNotCreator)]
    fun test_init_unauthorized(aptosino: &signer) {
        state_based_game::init(aptosino, TestGame {});
    }
    
    #[test(aptosino=@aptosino)]
    #[expected_failure(abort_code=state_based_game::EGameAlreadyInitialized)]
    fun test_init_twice(aptosino: &signer) {
        state_based_game::init(aptosino, TestGame {});
        state_based_game::init(aptosino, TestGame {});
    }
    
    #[test(aptosino=@aptosino)]
    fun test_add_player(aptosino: &signer) {
        state_based_game::init(aptosino, TestGame {});
        state_based_game::add_player_game(PLAYER_ADDRESS, GAME_ADDRESS, TestGame {});
        assert!(state_based_game::get_is_player_in_game<TestGame>(PLAYER_ADDRESS), 0);
        assert!(state_based_game::get_player_game_address<TestGame>(PLAYER_ADDRESS) == GAME_ADDRESS, 0);
    }
    
    #[test]
    #[expected_failure(abort_code=state_based_game::EGameNotInitialized)]
    fun test_add_player_not_initialized() {
        state_based_game::add_player_game(PLAYER_ADDRESS, GAME_ADDRESS, TestGame {});
    }
    
    #[test(aptosino=@aptosino)]
    #[expected_failure(abort_code=state_based_game::EPlayerAlreadyInGame)]
    fun test_add_player_twice(aptosino: &signer) {
        state_based_game::init(aptosino, TestGame {});
        state_based_game::add_player_game(PLAYER_ADDRESS, GAME_ADDRESS, TestGame {});
        state_based_game::add_player_game(PLAYER_ADDRESS, GAME_ADDRESS, TestGame {});
    }
    
    #[test(aptosino=@aptosino)]
    fun test_remove_player(aptosino: &signer) {
        state_based_game::init(aptosino, TestGame {});
        state_based_game::add_player_game(PLAYER_ADDRESS, GAME_ADDRESS, TestGame {});
        state_based_game::remove_player_game(PLAYER_ADDRESS, TestGame {});
        assert!(state_based_game::get_is_player_in_game<TestGame>(PLAYER_ADDRESS) == false, 0);
    }
    
    #[test]
    #[expected_failure(abort_code=state_based_game::EGameNotInitialized)]
    fun test_remove_player_not_initialized() {
        state_based_game::remove_player_game(PLAYER_ADDRESS, TestGame {});
    }
    
    #[test(aptosino=@aptosino)]
    #[expected_failure(abort_code=state_based_game::EPlayerNotInGame)]
    fun test_remove_player_not_in_game(aptosino: &signer) {
        state_based_game::init(aptosino, TestGame {});
        state_based_game::remove_player_game(PLAYER_ADDRESS, TestGame {});
    }
    
    #[test(aptosino=@aptosino)]
    #[expected_failure(abort_code=state_based_game::EPlayerNotInGame)]
    fun test_remove_player_twice(aptosino: &signer) {
        state_based_game::init(aptosino, TestGame {});
        state_based_game::add_player_game(PLAYER_ADDRESS, GAME_ADDRESS, TestGame {});
        state_based_game::remove_player_game(PLAYER_ADDRESS, TestGame {});
        state_based_game::remove_player_game(PLAYER_ADDRESS, TestGame {});
    }
    
    #[test(aptosino=@aptosino)]
    #[expected_failure(abort_code=state_based_game::EPlayerNotInGame)]
    fun test_get_player_game_address_not_added(aptosino: &signer) {
        state_based_game::init(aptosino, TestGame {});
        state_based_game::get_player_game_address<TestGame>(PLAYER_ADDRESS);
    }
}
