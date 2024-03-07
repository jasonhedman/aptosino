module aptosino::mines {

    use std::signer;
    use std::vector;

    use aptos_framework::event;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::randomness;

    use aptosino::house;
    use aptosino::state_based_game;
    
    // constants

    const MAX_ROWS: u8 = 100;
    const MAX_COLS: u8 = 100;

    // error codes
    
    /// The mines board has invalid rows
    const EMinesMachineInvalidRows: u64 = 101;
    /// The mines board has invalid columns
    const EMinesMachineInvalidCols: u64 = 102;
    /// The mines board has invalid mines
    const EMinesMachineInvalidMines: u64 = 103;
    /// There are no more gems to reveal
    const ENoMoreGems: u64 = 104;
    /// A predicted outcome is out of range
    const EPredictedOutcomeOutOfRange: u64 = 105;
    /// The mines board has invalid mines
    const ECellIsRevealed: u64 = 106;

    // game type

    struct MinesGame has drop {}

    // structs

    /// Structure representing the mines board
    struct MinesBoard has key {
        /// The coordinates of the gems found by the player
        gem_coordinates: vector<vector<u8>>,
        /// The number of rows on the mines board
        num_rows: u8,
        /// The number of columns on the mines board
        num_cols: u8,
        /// The number of mines on the mines board
        num_mines: u8,
    }

    // events

    #[event]
    /// Event emitted when a mines board is created
    /// * player_address: the address of the player
    /// * bet_amount: the amount staked
    /// * num_rows: the number of rows on the mines board
    /// * num_cols: the number of columns on the mines board
    /// * num_mines: the number of mines on the mines board
    struct MinesMachineCreated has drop, store {
        /// The amount staked
        bet_amount: u64,
        /// The number of rows on the mines board
        num_rows: u8,
        /// The number of columns on the mines board
        num_cols: u8,
        /// The number of mines on the mines board
        num_mines: u8,
    }

    #[event]
    /// Event emitted when the player reveals a mine
    struct MineRevealed has drop, store {
        /// The address of the player
        player_address: address,
        /// The row of the cell selected
        predicted_row: u8,
        /// The column of the cell selected
        predicted_col: u8,
    }

    #[event]
    /// Event emitted when the selects a gem
    struct GemRevealed has drop, store {
        /// The address of the player
        player_address: address,
        /// The row of the cell selected
        predicted_row: u8,
        /// The column of the cell selected
        predicted_col: u8,
    }

    // admin functions
    
    /// Initializes the game
    /// * creator: the signer of the creator account
    public entry fun init(creator: &signer) {
        state_based_game::init(creator, MinesGame {});
    }

    /// Approves the game
    /// * admin: the signer of the admin account
    public entry fun approve_game(admin: &signer) {
        house::approve_game(admin, MinesGame {});
    }

    // game functions

    /// Creates the mines board
    /// * player: the signer of the player account
    /// * bet_amount: the amount to bet
    /// * num_rows: the number of rows on the mines board
    /// * num_cols: the number of columns on the mines board
    /// * num_mines: the number of mines on the mines board
    public entry fun create_board(
        player: &signer,
        bet_amount: u64,
        num_rows: u8,
        num_cols: u8,
        num_mines: u8,
    ) {
        assert_mines_board_valid(num_rows, num_cols, num_mines);
        
        let constructor_ref = state_based_game::create_game(player, bet_amount, MinesGame {});

        move_to(&object::generate_signer(&constructor_ref), MinesBoard {
            gem_coordinates: vector::empty<vector<u8>>(),
            num_rows,
            num_cols,
            num_mines,
        });

        event::emit<MinesMachineCreated>(
            MinesMachineCreated {
                bet_amount,
                num_rows,
                num_cols,
                num_mines,
            }
        );
    }

    /// Creates and verifies the mines board and pays out the player accordingly
    /// * player: the signer of the player account
    /// * mines_board: the mines board
    /// * predicted_outcomes: the coordinates of the cells to select
    /// * bet_amount: the amount to bet
    public entry fun select_cell(
        player: &signer,
        predicted_row: u8,
        predicted_col: u8,
    ) 
    acquires MinesBoard {
        let player_address = signer::address_of(player);
        let mines_board_obj = get_mines_board_object(player_address);
        let mines_board = borrow_global<MinesBoard>(object::object_address(&mines_board_obj));
        assert_predicted_outcome_is_valid(predicted_row, predicted_col, mines_board);
        let is_mine = randomness::u8_range(0, remaining_cells(mines_board)) < mines_board.num_mines;
        select_cell_impl(player_address, predicted_row, predicted_col, is_mine);
    }

    /// Cashes out the player and deletes the mines board
    /// * player: the signer of the player account
    /// * mines_board_obj: the mines board object
    public entry fun cash_out(player: &signer) acquires MinesBoard {
        let player_address = signer::address_of(player);
        let mines_address = state_based_game::get_player_game_address<MinesGame>(player_address);
        let mines_board = move_from<MinesBoard>(mines_address);
        let MinesBoard {
            gem_coordinates,
            num_rows,
            num_cols,
            num_mines,
        } = mines_board;
        let (payout_numerator, payout_denominator) = payout_multiplier(
            (num_rows as u64) * (num_cols as u64),
            (num_mines as u64),
            vector::length(&gem_coordinates)
        );
        state_based_game::resolve_game(player_address, payout_numerator, payout_denominator, MinesGame {});
    }
    
    // implementation functions
    
    /// Implementation of logic when player selects a cell
    /// * mines_board_obj: the mines board object
    /// * predicted_row: the row of the cell selected
    /// * predicted_col: the column of the cell selected
    /// * is_mine: whether the cell selected is a mine
    fun select_cell_impl(
        player_address: address,
        predicted_row: u8,
        predicted_col: u8,
        is_mine: bool,
    ) acquires MinesBoard {
        if(is_mine) {
            select_mine(player_address, predicted_row, predicted_col);
        } else {
            select_gem(player_address, predicted_row, predicted_col);
        }
    }

    /// Implementation of logic when player selects a mine
    /// * mines_board_obj: the mines board object
    /// * predicted_row: the row of the cell selected
    /// * predicted_col: the column of the cell selected
    fun select_mine(player_address: address, predicted_row: u8, predicted_col: u8) 
    acquires MinesBoard {
        let mines_board_obj = get_mines_board_object(player_address);
        let mines_board = move_from<MinesBoard>(object::object_address(&mines_board_obj));
        let MinesBoard {
            gem_coordinates: _,
            num_rows: _,
            num_cols: _,
            num_mines: _,
        } = mines_board;
        state_based_game::resolve_game(player_address, 0, 1, MinesGame {}, );
        event::emit<MineRevealed>(
            MineRevealed {
                player_address,
                predicted_row,
                predicted_col,
            }
        );
    }

    /// Implementation of logic when player selects a gem
    /// * mines_board_obj: the mines board object
    /// * predicted_row: the row of the cell selected
    /// * predicted_col: the column of the cell selected
    fun select_gem(
        player_address: address,
        predicted_row: u8,
        predicted_col: u8,
    ) 
    acquires MinesBoard {
        let mines_board_obj = get_mines_board_object(player_address);
        let mines_board = borrow_global_mut<MinesBoard>(object::object_address(&mines_board_obj));
        vector::push_back(&mut mines_board.gem_coordinates, vector[predicted_row, predicted_col]);
        event::emit<GemRevealed>(
            GemRevealed {
                player_address,
                predicted_row,
                predicted_col,
            }
        );
    }

    // getters
    
    #[view]
    /// Returns the number of rows on the mines board
    /// * player_address: the address of the player
    public fun get_num_rows(player_address: address): u8 acquires MinesBoard {
        borrow_global<MinesBoard>(state_based_game::get_player_game_address<MinesGame>(player_address)).num_rows
    }
    
    #[view]
    /// Returns the number of columns on the mines board
    /// * player_address: the address of the player
    public fun get_num_cols(player_address: address): u8 acquires MinesBoard {
        borrow_global<MinesBoard>(state_based_game::get_player_game_address<MinesGame>(player_address)).num_cols
    }
    
    #[view]
    /// Returns the number of mines on the mines board
    /// * player_address: the address of the player
    public fun get_num_mines(player_address: address): u8 acquires MinesBoard {
        borrow_global<MinesBoard>(state_based_game::get_player_game_address<MinesGame>(player_address)).num_mines
    }
    
    #[view]
    /// Returns the gem coordinates found by the player
    /// * player_address: the address of the player
    public fun get_gem_coordinates(player_address: address): vector<vector<u8>> acquires MinesBoard {
        borrow_global<MinesBoard>(state_based_game::get_player_game_address<MinesGame>(player_address)).gem_coordinates
    }

    #[view]
    /// Returns the payout multiplier for a given bet
    /// * bet_amount: the amount to bet
    /// * rows: the number of rows on the mines board
    /// * cols: the number of columns on the mines board
    /// * mines: the number of mines on the mines board
    /// * revealed: the coordinates of the revealed cells
    public fun get_payout_multiplier(mines_board_obj: Object<MinesBoard>): (u64, u64) acquires MinesBoard {
        let mines_board = borrow_global<MinesBoard>(object::object_address(&mines_board_obj));
        payout_multiplier(
            (mines_board.num_rows as u64) * (mines_board.num_cols as u64), 
            (mines_board.num_mines as u64), 
            vector::length(&mines_board.gem_coordinates)
        )
    }
    
    #[view]
    /// Returns the game object of the player
    /// * player_address: the address of the player
    public fun get_mines_board_object(player_address: address): Object<MinesBoard> {
        state_based_game::get_game_object<MinesGame, MinesBoard>(player_address)
    }

    // private getters

    /// Returns the number of remaining cells on the mines board
    /// * mines_board: the mines board
    fun remaining_cells(mines_board: &MinesBoard): u8 {
        mines_board.num_rows * mines_board.num_cols - 
            (vector::length<vector<u8>>(&mines_board.gem_coordinates) as u8)
    }

    /// Returns the number of remaining mines in the mines board
    /// * mines_board: the mines board
    fun remaining_gems(mines_board: &MinesBoard): u8 {
        remaining_cells(mines_board) - mines_board.num_mines
    }

    /// Returns the payout multiplier for the current state of the mines board
    /// Calculated by inverting the probability of getting to the current state of the mines board
    /// nCr(n, g) / nCr(n - m, g)
    /// * n: the total number of cells
    /// * m: the number of mines
    /// * g: the number of gems found
    fun payout_multiplier(n: u64, m: u64, g: u64): (u64, u64) {
        let multiplier_numerator = 1;
        let multiplier_denominator = 1;
        let i = 0;
        while(i < g) {
            multiplier_numerator = multiplier_numerator * (n - i);
            multiplier_denominator = multiplier_denominator * (n - m - i);
            i = i + 1;
        };
        (multiplier_numerator, multiplier_denominator)
    }
    
    // assert statements

    /// Asserts that the mines board input is valid
    /// * num_rows: the number of rows on the mines board
    /// * num_cols: the number of columns on the mines board
    /// * num_mines: the number of mines on the mines board
    fun assert_mines_board_valid(num_rows: u8, num_cols: u8, num_mines: u8) {
        assert!(num_rows > 0 && num_rows <= MAX_ROWS, EMinesMachineInvalidRows);
        assert!(num_cols > 0 && num_cols <= MAX_COLS, EMinesMachineInvalidCols);
        assert!(num_mines > 0 && num_mines < num_rows * num_cols, EMinesMachineInvalidMines);
    }
    
    /// Asserts that each outcome in a vector of predicted outcomes is within the range of possible outcomes
    /// * predicted_row: the row of the cell selected
    /// * predicted_col: the column of the cell selected
    /// * mines_board: the mines board
    fun assert_predicted_outcome_is_valid(predicted_row: u8, predicted_col: u8, mines_board: &MinesBoard) {
        assert!(predicted_row < mines_board.num_rows, EPredictedOutcomeOutOfRange);
        assert!(predicted_col < mines_board.num_cols, EPredictedOutcomeOutOfRange);
        assert!(remaining_gems(mines_board) > 0, ENoMoreGems);
        assert!(!vector::contains<vector<u8>>(
            &mines_board.gem_coordinates, 
            &vector[predicted_row, predicted_col]
        ), ECellIsRevealed);
    }
    // test functions
    
    #[test_only]
    public fun test_select_cell(
        player_address: address,
        predicted_row: u8,
        predicted_col: u8,
        is_mine: bool,
    ) acquires MinesBoard {
        select_cell_impl(player_address, predicted_row, predicted_col, is_mine);
    }

    #[test_only]
    public fun test_select_mine(
        player_address: address,
        predicted_row: u8,
        predicted_col: u8,
    ) acquires MinesBoard {
        select_mine(player_address, predicted_row, predicted_col);
    }

    #[test_only]
    public fun test_select_gem(
        player_address: address,
        predicted_row: u8,
        predicted_col: u8,
    ) acquires MinesBoard {
        select_gem(player_address, predicted_row, predicted_col);
    }
}