// Pass sequence transactions to the driver.
class Sequencer extends uvm_sequencer #(transaction);
    `uvm_component_utils(Sequencer)
    function new(string name = "Sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass
