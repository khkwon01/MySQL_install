const session = mysql.getSession("admin:Welcome#1@10.1.1.12");

// Set the session as the active global session
shell.setSession(session);

// Perform a schema dump with  options
try {
    // Perform the schema dump
    print("Starting dump of schema(s): qb");
    util.dumpSchemas(['qb'], './qbdump', {
        threads: 2,
	showProgress: true,
        ocimds: true, // Enable OCI MDS metadata
	//consistent: false,  // consistent lock disable
	//compatibility: ["strip_definers", "strip_restricted_grants", "ignore_missing_pks"],  //pks 없는 에러 무시
	compatibility: ["strip_definers", "strip_restricted_grants", "create_invisible_pks", "force_innodb","skip_invalid_accounts","strip_tablespaces"]
    });
    
    // If successful, print a confirmation message
    print("Dump completed successfully.");
} catch (err) {
    // If an error occurs, print the error and exit the script
    print("\nError during dump: " + err.message);
    shell.exit(1)
}

// Close the session when done
session.close();
