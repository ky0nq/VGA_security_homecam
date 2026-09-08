// Create board verification components and connect monitors to general checkers.
class Environment extends uvm_env;
    `uvm_component_utils(Environment)
    
    Agent      board1_agent;
    Agent      board2_agent;
    Scoreboard board1_scb;
    Scoreboard board2_scb;
    Coverage   board1_cov;
    Coverage   board2_cov;
    AuthScoreboard auth_scb;
    AuthCoverage auth_cov;
    string test_mode;

    function new(string name = "Environment", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        board1_agent = Agent::type_id::create("board1_agent", this);
        board2_agent = Agent::type_id::create("board2_agent", this);
        board1_scb   = Scoreboard::type_id::create("board1_scb", this);
        board2_scb   = Scoreboard::type_id::create("board2_scb", this);
        uvm_config_db#(bit)::set(this, "board1_cov", "control_enable", 1'b1);
        uvm_config_db#(bit)::set(this, "board2_cov", "control_enable", 1'b0);
        board1_cov   = Coverage::type_id::create("board1_cov", this);
        board2_cov   = Coverage::type_id::create("board2_cov", this);
        auth_scb     = AuthScoreboard::type_id::create("auth_scb", this);
        void'(uvm_config_db#(string)::get(this,"","test_mode",test_mode));
        if ((test_mode == "AUTH_SUCCESS") || (test_mode == "AUTH_LOCKOUT"))
            auth_cov = AuthCoverage::type_id::create("auth_cov", this);

    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        board1_agent.mon.send.connect(board1_scb.recv);
        board1_agent.mon.send.connect(board1_cov.analysis_export);
        board2_agent.mon.send.connect(board2_scb.recv);
        board2_agent.mon.send.connect(board2_cov.analysis_export);
    endfunction

endclass
