// load.js - loaded the dump file into 8.x
// Connect to the server - change the credentials
const session = mysql.getSession("admin:Welcome#1@10.1.1.14");

// Set the session as the active global session
shell.setSession(session);

// Load the dump with the `ocimds` option enabled
try {
    util.loadDump('./qbdump', {
        threads: 2,
	dryrun: true,    // change from true to false in exeution
        resetProgress: true,
        ignoreVersion: true,
	// createInvisiblePKs: true,  //invisible pk 생성시
	ignoreExistingObjects: true,
	deferTableIndexes: 'all'
	// excludeSchemas:["AutoML","ragdb"],
	// excludeTables:["airport.passenger_survey"]
    });

    // If successful, print a confirmation message
    print("Schema load completed successfully.\n\n");
} catch (err) {
    // If an error occurs, print the error and exit the script
    print("\nError during load: " + err.message);
    shell.exit(1); // Exit with a non-zero status to indicate failure
}

// Close the session when done
session.close();
