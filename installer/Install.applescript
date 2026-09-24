on run
	set installer to POSIX path of (path to me) & "Contents/Resources/payload/install.sh"
	set args to " --gui"
	try
		set projects to choose folder with prompt "Choose the folder where you keep your projects. Agents may create, change and delete files there. Cancel to skip; you can edit the list later."
		set args to args & " --projects " & quoted form of POSIX path of projects
	end try
	try
		do shell script "/bin/zsh " & quoted form of installer & args
	on error errorText
		display alert "OpenCode Guard install failed" message errorText as critical
	end try
end run
