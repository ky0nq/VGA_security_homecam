// Custom UVM report message format.
class my_report_server extends uvm_default_report_server;

    virtual function string compose_report_message(
        uvm_report_message report_message,
        string report_object_name = ""
    );
        uvm_severity severity;
        uvm_verbosity verbosity;
        uvm_action action;

        string id;
        string message;
        string filename;
        string context_report;
        string obj_name;

        int line;
        time t;

        uvm_report_object report_object;
        severity = report_message.get_severity();
		verbosity = uvm_verbosity'(report_message.get_verbosity());
        action = report_message.get_action();
        id = report_message.get_id();
        message = report_message.get_message();
        filename = report_message.get_filename();
        line = report_message.get_line();
        context_report = report_message.get_context();
        t = $time;
        report_object = report_message.get_report_object();

        if (report_object != null)obj_name = report_object.get_full_name();
        else			  obj_name = report_object_name;

        return $sformatf("[%0t] [%s] [%s] %s", t, severity.name(), id, message); 
    endfunction
endclass
