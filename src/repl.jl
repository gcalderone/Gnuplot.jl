using REPL, ReplMaker

# --------------------------------------------------------------------
"""
    Gnuplot.init_repl(; start_key='>')

Install a hook to replace the common Julia REPL with a gnuplot one.  The key to start the REPL is the one provided in `start_key` (default: `>`).

Note: the gnuplot REPL operates only on the default session.
"""
function repl_init(; start_key='>')
    function repl_exec(s)
        println(GnuplotProcess.sendcmd_capture_reply(getsession().process, s))
        nothing
    end

    function repl_isvalid(s)
        input = strip(String(take!(copy(REPL.LineEdit.buffer(s)))))
        (length(input) == 0)  ||  (input[end] != '\\')
    end

    initrepl(repl_exec,
             prompt_text="gnuplot> ",
             prompt_color = :blue,
             start_key=start_key,
             mode_name="Gnuplot",
             completion_provider=REPL.LineEdit.EmptyCompletionProvider(),
             valid_input_checker=repl_isvalid)
end
