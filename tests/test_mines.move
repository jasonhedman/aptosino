#[test_only]
module aptosino::test_mines {

    use std::signer;
    use std::vector;
    
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;

    use aptosino::test_helpers;
    use aptosino::house;
    use aptosino::mines;

    const INITIAL_DEPOSIT: u64 = 10_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const FEE_DIVISOR: u64 = 10_000;
    const BET_AMOUNT: u64 = 1_000_000;

    fun setup_mines(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );
        mines::approve_game(aptosino);
        mines::init(aptosino);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_create_mines_board(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);
        let player_address = signer::address_of(player);
        assert!(mines::get_num_rows(player_address) == 5, 0);
        assert!(mines::get_num_cols(player_address) == 5, 0);
        assert!(mines::get_num_mines(player_address) == 1, 0);
        assert!(mines::get_bet_amount(player_address) == BET_AMOUNT, 0);
        assert!(vector::length(&mines::get_gem_coordinates(player_address)) == 0, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=mines::EMinesMachineInvalidRows)]
    fun test_create_mines_board_invalid_rows(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 0, 5, 1);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=mines::EMinesMachineInvalidCols)]
    fun test_create_mines_board_invalid_cols(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 0, 1);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=mines::EMinesMachineInvalidMines)]
    fun test_create_mines_board_zero_mines(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 5, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=mines::EMinesMachineInvalidMines)]
    fun test_create_mines_board_too_many_mines(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 5, 25);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_select_gem(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);
        
        let player_address = signer::address_of(player);
        mines::test_select_gem(player_address, 0, 0);
        
        let gem_coordinates = mines::get_gem_coordinates(player_address);
        assert!(*vector::borrow(&gem_coordinates, 0) == vector[0, 0], 0);
        
        let (payout_numerator, payout_denominator) = mines::get_payout_multiplier(
            mines::get_mines_board_object(player_address),
        );
        assert!(payout_numerator == 25, 0);
        assert!(payout_denominator == 24, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_select_mine_no_gems(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);
        
        let player_address = signer::address_of(player);
        mines::test_select_mine(player_address, 0, 0);
        
        assert!(house::get_house_balance() == INITIAL_DEPOSIT + BET_AMOUNT, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_select_mine_with_gems(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);

        let player_address = signer::address_of(player);
        
        mines::test_select_gem(player_address, 0, 0);
        mines::test_select_mine(player_address, 0, 1);
        
        assert!(house::get_house_balance() == INITIAL_DEPOSIT + BET_AMOUNT, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_cash_out_one_gem(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);

        let player_address = signer::address_of(player);
        
        mines::test_select_gem(player_address, 0, 0);
        
        let (payout_numerator, payout_denominator) = mines::get_payout_multiplier(
            mines::get_mines_board_object(player_address),
        );
        let fee = house::get_fee_amount(BET_AMOUNT);
        
        mines::cash_out(player);
        
        let payout = (BET_AMOUNT * payout_numerator) / payout_denominator;
        
        assert!(house::get_house_balance() == INITIAL_DEPOSIT + BET_AMOUNT - payout + fee, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_cash_out_two_gems(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);

        let player_address = signer::address_of(player);
        
        mines::test_select_gem(player_address, 0, 0);
        mines::test_select_gem(player_address, 0, 1);
        
        let (payout_numerator, payout_denominator) = mines::get_payout_multiplier(
            mines::get_mines_board_object(player_address),
        );
        let fee = house::get_fee_amount(BET_AMOUNT);
        
        mines::cash_out(player);
        
        let payout = (BET_AMOUNT * payout_numerator) / payout_denominator;
        
        assert!(house::get_house_balance() == INITIAL_DEPOSIT + BET_AMOUNT - payout + fee, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_select_cell_gem(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);
        let player_address = signer::address_of(player);
        mines::test_select_cell(player_address, 0, 0, false);
        assert!(vector::length(&mines::get_gem_coordinates(player_address)) == 1, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_select_cell_mine(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);
        mines::test_select_cell(signer::address_of(player), 0, 1, true);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_select_cell_entry(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);
        mines::test_select_cell_entry(player, 0, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=mines::EPredictedOutcomeOutOfRange)]
    fun test_select_cell_row_invalid(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);
        mines::test_select_cell_entry(player, 5, 4);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=mines::EPredictedOutcomeOutOfRange)]
    fun test_select_cell_col_invalid(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 5, 5, 1);
        mines::test_select_cell_entry(player, 4, 5);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=mines::ECellIsRevealed)]
    fun test_select_cell_revealed_cell(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 1, 3, 1);
        mines::test_select_gem(signer::address_of(player), 0, 0);
        mines::test_select_cell_entry(player, 0, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_select_last_gem(framework: &signer, aptosino: &signer, player: &signer) {
        setup_mines(framework, aptosino, player);
        mines::create_board(player, BET_AMOUNT, 1, 2, 1);
        let player_address = signer::address_of(player);
        let player_balance_before = coin::balance<AptosCoin>(player_address);
        mines::test_select_gem(signer::address_of(player), 0, 0);
        let fee = test_helpers::get_fee(BET_AMOUNT, FEE_BPS, FEE_DIVISOR);
        assert!(coin::balance<AptosCoin>(player_address) - player_balance_before == BET_AMOUNT * 2 - fee, 0);
    }
}
