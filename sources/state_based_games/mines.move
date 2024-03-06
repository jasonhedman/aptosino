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
    
    /// The bet amount is zero
    const EBetAmountIsZero: u64 = 101;
    /// The mines machine has invalid rows
    const EMinesMachineInvalidRows: u64 = 102;
    /// The mines machine has invalid columns
    const EMinesMachineInvalidCols: u64 = 103;
    /// The mines machine has invalid mines
    const EMinesMachineInvalidMines: u64 = 104;
    /// There are no more gems to reveal
    const ENoMoreGems: u64 = 105;
    /// A predicted outcome is out of range
    const EPredictedOutcomeOutOfRange: u64 = 106;
    /// The mines machine has invalid mines
    const ECellIsRevealed: u64 = 107;

    // game type

    struct MinesGame has drop {}

    // structs

    /// Structure representing the mines machine
    struct MinesMachine has key {
        /// The coordinates of the gems found by the player
        gem_coordinates: vector<vector<u8>>,
        /// The number of rows in the mines machine
        num_rows: u8,
        /// The number of columns in the mines machine
        num_cols: u8,
        /// The number of mines in the mines machine
        num_mines: u8,
    }

    // events

    #[event]
    /// Event emitted when the mines machine is created
    /// * player_address: the address of the player
    /// * bet_amount: the amount staked
    /// * num_rows: the number of rows in the mines machine
    /// * num_cols: the number of columns in the mines machine
    /// * num_mines: the number of mines in the mines machine
    struct MinesMachineCreated has drop, store {
        /// The amount staked
        bet_amount: u64,
        /// The number of rows in the mines machine
        num_rows: u8,
        /// The number of columns in the mines machine
        num_cols: u8,
        /// The number of mines in the mines machine
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

    /// Approves the game
    /// * admin: the signer of the admin account
    public entry fun approve_game(admin: &signer) {
        house::approve_game(admin, MinesGame {});
    }

    // game functions

    /// Creates the mines machine
    /// * player: the signer of the player account
    /// * bet_amount: the amount to bet
    /// * num_rows: the number of rows in the mines machine
    /// * num_cols: the number of columns in the mines machine
    /// * num_mines: the number of mines in the mines machine
    public entry fun create_mines_machine(
        player: &signer,
        bet_amount: u64,
        num_rows: u8,
        num_cols: u8,
        num_mines: u8,
    ) 
    {
        assert_bet_is_valid(bet_amount);
        assert_mines_machine_valid(num_rows, num_cols, num_mines);

        let constructor_ref = state_based_game::create_game(player, bet_amount, MinesGame {});

        move_to(&object::generate_signer(&constructor_ref), MinesMachine {
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

    /// Creates and verifies the mines machine and pays out the player accordingly
    /// * player: the signer of the player account
    /// * mines_machine: the mines machine
    /// * predicted_outcomes: the coordinates of the cells to select
    /// * bet_amount: the amount to bet
    public entry fun select_cell(
        player: &signer,
        predicted_row: u8,
        predicted_col: u8,
    ) 
    acquires MinesMachine {
        let player_address = signer::address_of(player);
        let mines_machine_obj = get_mines_machine(player_address);
        let mines_machine = borrow_global<MinesMachine>(object::object_address(&mines_machine_obj));
        assert_predicted_outcome_is_valid(predicted_row, predicted_col, mines_machine);
        let is_mine = randomness::u8_range(0, remaining_cells(mines_machine)) < mines_machine.num_mines;
        if(is_mine) {
            select_mine(player_address, predicted_row, predicted_col);
        } else {
            select_gem(player_address, predicted_row, predicted_col);
        }
    }

    /// Cashes out the player and deletes the mines machine
    /// * player: the signer of the player account
    /// * mines_machine_obj: the mines machine object
    public entry fun cash_out(player: &signer) acquires MinesMachine {
        let player_address = signer::address_of(player);
        let mines_address = state_based_game::get_player_game_address<MinesGame>(player_address);
        let mines_machine = move_from<MinesMachine>(mines_address);
        let MinesMachine {
            gem_coordinates,
            num_rows,
            num_cols,
            num_mines,
        } = mines_machine;
        let (payout_numerator, payout_denominator) = payout_multiplier(
            (num_rows as u64) * (num_cols as u64),
            (num_mines as u64),
            vector::length(&gem_coordinates)
        );
        state_based_game::resolve_game(player_address, payout_numerator, payout_denominator, MinesGame {});
    }

    /// Implementation of logic when player selects a mine
    /// * mines_machine_obj: the mines machine object
    /// * predicted_row: the row of the cell selected
    /// * predicted_col: the column of the cell selected
    fun select_mine(player_address: address, predicted_row: u8, predicted_col: u8) 
    acquires MinesMachine {
        let mines_machine_obj = get_mines_machine(player_address);
        let mines_machine = move_from<MinesMachine>(object::object_address(&mines_machine_obj));
        let MinesMachine {
            gem_coordinates: _,
            num_rows: _,
            num_cols: _,
            num_mines: _,
        } = mines_machine;
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
    /// * mines_machine_obj: the mines machine object
    /// * predicted_row: the row of the cell selected
    /// * predicted_col: the column of the cell selected
    fun select_gem(
        player_address: address,
        predicted_row: u8,
        predicted_col: u8,
    ) 
    acquires MinesMachine {
        let mines_machine_obj = get_mines_machine(player_address);
        let mines_machine = borrow_global_mut<MinesMachine>(object::object_address(&mines_machine_obj));
        vector::push_back(&mut mines_machine.gem_coordinates, vector[predicted_row, predicted_col]);
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
    /// Returns the payout multiplier for a given bet
    /// * bet_amount: the amount to bet
    /// * rows: the number of rows in the mines machine
    /// * cols: the number of columns in the mines machine
    /// * mines: the number of mines in the mines machine
    /// * revealed: the coordinates of the revealed cells
    public fun get_payout_multiplier(mines_machine_obj: Object<MinesMachine>): (u64, u64) acquires MinesMachine {
        let mines_machine = borrow_global<MinesMachine>(object::object_address(&mines_machine_obj));
        payout_multiplier(
            (mines_machine.num_rows as u64) * (mines_machine.num_cols as u64), 
            (mines_machine.num_mines as u64), 
            vector::length(&mines_machine.gem_coordinates)
        )
    }
    
    #[view]
    /// Returns the game object of the player
    /// * player_address: the address of the player
    public fun get_mines_machine(player_address: address): Object<MinesMachine> {
        state_based_game::get_game_object<MinesGame, MinesMachine>(player_address)
    }

    // private getters

    /// Returns the number of remaining cells in the mines machine
    /// * mines_machine: the mines machine
    fun remaining_cells(mines_machine: &MinesMachine): u8 {
        mines_machine.num_rows * mines_machine.num_cols - 
            (vector::length<vector<u8>>(&mines_machine.gem_coordinates) as u8)
    }

    /// Returns the number of remaining mines in the mines machine
    /// * mines_machine: the mines machine
    fun remaining_gems(mines_machine: &MinesMachine): u8 {
        remaining_cells(mines_machine) - mines_machine.num_mines
    }

    /// Returns the payout multiplier for the current state of the mines machine
    /// Calculated by inverting the probability of getting to the current state of the mines machine
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


    /// Asserts that the bet is non-zero
    fun assert_bet_is_valid(bet: u64) {
        assert!(bet > 0, EBetAmountIsZero);
    }

    /// Asserts that the mines machine input is valid
    /// * num_rows: the number of rows in the mines machine
    /// * num_cols: the number of columns in the mines machine
    /// * num_mines: the number of mines in the mines machine
    fun assert_mines_machine_valid(num_rows: u8, num_cols: u8, num_mines: u8) {
        assert!(num_cols > 0 && num_rows <= MAX_ROWS, EMinesMachineInvalidRows);
        assert!(num_cols > 0 && num_cols <= MAX_COLS, EMinesMachineInvalidCols);
        assert!(num_mines > 0 && num_mines < num_rows * num_cols, EMinesMachineInvalidMines);
    }
    
    /// Asserts that each outcome in a vector of predicted outcomes is within the range of possible outcomes
    /// * predicted_row: the row of the cell selected
    /// * predicted_col: the column of the cell selected
    /// * mines_machine: the mines machine
    fun assert_predicted_outcome_is_valid(predicted_row: u8, predicted_col: u8, mines_machine: &MinesMachine) {
        assert!(predicted_row < mines_machine.num_rows, EPredictedOutcomeOutOfRange);
        assert!(predicted_col < mines_machine.num_cols, EPredictedOutcomeOutOfRange);
        assert!(remaining_gems(mines_machine) > 0, ENoMoreGems);
        assert!(!vector::contains<vector<u8>>(
            &mines_machine.gem_coordinates, 
            &vector[predicted_row, predicted_col]
        ), ECellIsRevealed);
    }
    // test functions

    #[test_only]
    public fun select_mine_impl(
        player_address: address,
        predicted_row: u8,
        predicted_col: u8,
    ) acquires MinesMachine {
        select_mine(player_address, predicted_row, predicted_col);
    }

    #[test_only]
    public fun select_gem_impl(
        player_address: address,
        predicted_row: u8,
        predicted_col: u8,
    ) acquires MinesMachine {
        select_gem(player_address, predicted_row, predicted_col);
    }
}