# pg_hl7
postgres extentions for handling hl7

this is intended to be a two part Compose project, enabling a MIRTH DOcker client to use postgres as a backend dbase for its HL7 channel configuration (via mirthdb) as well as a persistent dbase for the processed HL7 inputs (rsnadb).

For the status of each component, refer to the READMEs in their respective folders

# to Use and Deploy this Stack


### Clone this repo 
---
	git clone  https://github.com/sglanger/ph_hl7
---


### Build the stack
---
	sudo docker-compose build
---

### To launch the stack
---
	sudo docker-compose up
---

Wait for the services to start, and then you should be able to point your browser at the normal Mirth control URL
---
	http://yourhost:8080
---

and see the usual MIRTH control installer. GO ahead and the the java web start control and initiate Mirth then install any relvent HL7 channels you hav for your site. They will be stored to the postgres dbase. For the HL7 channel, make sure it points to the correct postgres endpoint also, for example

---
	DatabaseConnectionFactory.createDatabaseConnection('org.postgresql.Driver', 'jdbc:postgresql://127.0.0.1:5432/rsnadb','edge','d17bK4#M');
---

With all containers in this stack running you shuold see the follow new ports exposed on your docker host

* '5432': postgres
* '8080': mirth java webstart downloaded
* '8443': mirth control port

You will also see the folling volumes created
* 'postgres-data': for the postgres tables




