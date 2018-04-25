# pg_hl7: dbase
postgres extentions for handling hl7

this is intended to be used as the dbase part of a two part Compose project, the other part would be the MIRTH DOcker client.


Dbase Status;
-----------
Builds, runs, have to build the schema after launch by connecting and running script load_sql.sh [for reasons I have not had time to figure out loading the schema at build kills the launch]

To Do: set up volumes for dbase persistence [may end up doing this in compose.yaml]
