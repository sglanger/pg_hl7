# pg_hl7
postgres extentions for handling hl7

this is intended to be a two part Compose project, enabling a MIRTH Docker client to use postgres as a backend dbase for its HL7 channel configuration (via mirthdb) as well as a persistent dbase for the processed HL7 inputs (rsnadb).

For the status of each component, refer to the READMEs in their respective folders. They work in a standalone fashion now (4-25). When the below is finished they will work under the control of the single compose.yaml file


### to Use and Deploy this Stack under Compose (all below is pending)


### Clone this repo 
---
	git clone  https://github.com/sglanger/pg_hl7
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

and see the usual MIRTH control installer. Go ahead and get the java webstart control and initiate Mirth then install any relevent HL7 channels you have for your site. They will be stored to the postgres dbase. For the HL7 channel, make sure it points to the correct postgres endpoint also, for example

---
	DatabaseConnectionFactory.createDatabaseConnection('org.postgresql.Driver', 'jdbc:postgresql://127.0.0.1:5432/rsnadb','edge','yourpasshere');
---

With all containers running you should see the follow new ports exposed on your docker host

* '5432': postgres
* '8080': mirth java webstart downloader
* '8443': mirth control port

You will also see the following volumes created
* 'postgres-data': for the postgres tables




