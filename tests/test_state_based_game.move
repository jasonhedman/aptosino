#[test_only]
module aptosino::test_state_based_game {

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    
    use aptosino::house;
    use aptosino::test_helpers;
    use aptosino::state_based_game;
    
    struct TestGame has drop {}
    
    const INITIAL_DEPOSIT: u64 = 10_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const FEE_DIVISOR: u64 = 10_000;
    const BET_AMOUNT: u64 = 1_000_000;
    
    #[test(framework=@aptos_framework, aptosino=@aptosino)]
    fun test_init(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(
            framework,
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        house::approve_game(aptosino, TestGame {});
        state_based_game::init(aptosino, TestGame {});
        assert!(state_based_game::get_is_game_initialized<TestGame>(), 0);
    }

    #[test(framework=@aptos_framework, aptosino=@aptosino, non_aptosino=@0x101)]
    #[expected_failure(abort_code=state_based_game::ECallerNotCreator)]
    fun test_init_unauthorized(framework: &signer, aptosino: &signer, non_aptosino: &signer) {
        test_helpers::setup_house(
            framework,
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        house::approve_game(aptosino, TestGame {});
        state_based_game::init(non_aptosino, TestGame {});
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino)]
    #[expected_failure(abort_code=state_based_game::EGameAlreadyInitialized)]
    fun test_init_twice(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(
            framework,
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        house::approve_game(aptosino, TestGame {});
        state_based_game::init(aptosino, TestGame {});
        state_based_game::init(aptosino, TestGame {});
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino)]
    #[expected_failure(abort_code=state_based_game::EGameNotApproved)]
    fun test_init_game_not_approved(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(
            framework,
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        state_based_game::init(aptosino, TestGame {});
    }
    
    fun setup_tests(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework, 
            aptosino, 
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        house::approve_game(aptosino, TestGame {});
        state_based_game::init(aptosino, TestGame {});
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_create_game(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        let player_balance_before = coin::balance<AptosCoin>(@0x101);
        state_based_game::create_game(player, BET_AMOUNT, TestGame {});
        assert!(state_based_game::get_is_player_in_game<TestGame>(@0x101), 0);
        assert!(state_based_game::get_player_game_address<TestGame>(@0x101) != @0x0, 0);
        assert!(state_based_game::get_player_bet_amount<TestGame>(@0x101) == BET_AMOUNT, 0);
        assert!(coin::balance<AptosCoin>(@0x101) == player_balance_before - BET_AMOUNT, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=state_based_game::EGameNotInitialized)]
    fun test_create_game_not_initialized(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        state_based_game::create_game(player, BET_AMOUNT, TestGame {});
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=state_based_game::EGameNotApproved)]
    fun test_create_game_not_approved(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        house::approve_game(aptosino, TestGame {});
        state_based_game::init(aptosino, TestGame {});
        house::revoke_game<TestGame>(aptosino);
        state_based_game::create_game(player, BET_AMOUNT, TestGame {});
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=state_based_game::EPlayerAlreadyInGame)]
    fun test_create_game_twice(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        state_based_game::create_game(player, BET_AMOUNT, TestGame {});
        state_based_game::create_game(player, BET_AMOUNT, TestGame {});
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=state_based_game::EPlayerInsufficientBalance)]
    fun test_add_player_insufficient_balance(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        house::approve_game(aptosino, TestGame {});
        state_based_game::init(aptosino, TestGame {});
        state_based_game::create_game(player, MAX_BET + 2, TestGame {});
    }

    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_resolve_game_win(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        let player_balance_before = coin::balance<AptosCoin>(@0x101);
        state_based_game::create_game(player, BET_AMOUNT, TestGame {});
        state_based_game::resolve_game(@0x101, 2, 1, TestGame {});
        assert!(state_based_game::get_is_player_in_game<TestGame>(@0x101) == false, 0);
        let fee = house::get_fee_amount(BET_AMOUNT);
        assert!(coin::balance<AptosCoin>(@0x101) == player_balance_before + BET_AMOUNT - fee, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_resolve_game_lose(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        let player_balance_before = coin::balance<AptosCoin>(@0x101);
        state_based_game::create_game(player, BET_AMOUNT, TestGame {});
        state_based_game::resolve_game(@0x101, 0, 1, TestGame {});
        assert!(state_based_game::get_is_player_in_game<TestGame>(@0x101) == false, 0);
        assert!(coin::balance<AptosCoin>(@0x101) == player_balance_before - BET_AMOUNT, 0);
    }

    #[test]
    #[expected_failure(abort_code=state_based_game::EGameNotInitialized)]
    fun test_resolve_game_not_initialized() {
        state_based_game::resolve_game(@0x101, 1, 1, TestGame {});
    }

    #[test(framework=@aptos_framework, aptosino=@aptosino)]
    #[expected_failure(abort_code=state_based_game::EPlayerNotInGame)]
    fun test_resolve_game_not_in_game(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(
            framework,
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        house::approve_game(aptosino, TestGame {});
        state_based_game::init(aptosino, TestGame {});
        state_based_game::resolve_game(@0x101, 1, 1, TestGame {});
    }
    

    #[test(framework=@aptos_framework, aptosino=@aptosino)]
    #[expected_failure(abort_code=state_based_game::EPlayerNotInGame)]
    fun test_get_player_game_address_not_added(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(
            framework,
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        house::approve_game(aptosino, TestGame {});
        state_based_game::init(aptosino, TestGame {});
        state_based_game::get_player_game_address<TestGame>(@0x101);
    }
}
