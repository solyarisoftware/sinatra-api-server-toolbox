# Sinatra API Server Demo 

Realize a simple API server demo using [sinatra](http://www.sinatrarb.com/), returning data in JSON format.

Let consider this requirements: 

- To publish some API endpoint to share data already stored in different databases. 
- To access to some tables from TWO different ALREADY EXISTING (postgreSQL) databases, 
- To access them using activerecord ORM, so I used [sinatra-activerecord gem](https://github.com/janko-m/sinatra-activerecord) that allow to interact with DBs through activerecord ORM.

As proof of concept I supplied some Sinatra endpoints to manage a pseudo-REST idiom, a very-very simple authorization key example, some data query and routing, files upload/download. Always returning JSON. 


```
   .----------------------------------.
   |                                  |
   | API Client (curl/webclient/etc.) |
   |                                  |
   .----------------------------------.                             
         |      ^
         |      |      
         |      2: JSON data
         1: HTTP requests
         |      |                                       API SERVER
   .--------------------------------------------------------------.      
   |     |      |                                                 |  
   |     v      |                                                 |
   | .------------------------------.                             |
   | | Sinatra API Server           |                             |
   | |                              |     .--------------------.  |   
   | | Controller/Router logic      |<----| AUTH-KEY Archive:  |  |
   | |                              |     | .../db/app.keys    |  |   
   | |                              |     .--------------------.  |   
   | +------------------------------+                             |
   | | ActiveRecord ORM             |                             |   
   | .---+--------------------------.                             |
   |     |                                                        |
   |     |   .-------------------------------------------------.  |
   |     +---| postgreSQL DB 1 (default/base) with tables:     |  |
   |     |   |                                                 |  | 
   |     |   | .------. .------. .--------.                    |  | 
   |     |   | | Exam | | User | | Course |                    |  | 
   |     |   | .------. .------. .--------.                    |  | 
   |     |   .-------------------------------------------------.  |
   |     |   .-------------------------------------------------.  |
   |     +---| postgreSQL DB 2 (external/remote) with tables:  |  |
   |         |                                                 |  | 
   |         | .------.                                        |  | 
   |         | | Note |                                        |  | 
   |         | .------.                                        |  | 
   |         .-------------------------------------------------.  |
   .--------------------------------------------------------------.
```


Dev Tips:
- I used [curl](http://curl.haxx.se/docs/httpscripting.html) as default command line tool for doing client-side tests.
- I supplied a simple web client test app [using jQuery AJAX](https://github.com/solyaris/sinatra-api-server-demo#web-client-side-api-calls-using-jquery-ajax) 

To reproduce the Rails developer usual experience:  
-  I enjoyed use of [shotgun](https://github.com/rtomayko/shotgun) to automatically reload rack development server.
- I used very useful [tux](https://github.com/cldwalker/tux) developement environment to browse ActiveRecord models and doying queries, a la *rails console*. Last but not least I find useful [Hirb](https://github.com/cldwalker/hirb) gem, to display record data set in pretty print data tables.


# Using ActiveRecord ORM

In this sample application, I want connect with two already living databases (let say you already have in production some *legacy* database and you want to access these data with an API server):

I used a real case scenario (of my customer's database), where the *default* db is the postgreSQL database with name: `esamiAnatomia_development`, that contain three tables: 
- `Exam` 
- `User` 
- `Course`

The source code to connect the database is so simple as: 
```ruby
ActiveRecord::Base.establish_connection(ENV['ESAMIANATOMIA_DB_URL'] || \
  'postgres://YOURUSERNAME:YOURPASSWORD@HOSTIPADDRESS/esamiAnatomia_development')

class Exam < ActiveRecord::Base
end
class User < ActiveRecord::Base
end
class Course < ActiveRecord::Base
end
```

I want to connect also to a second different postgreSQL database named `sar`, containing table: 
- `Note`

Here below the table columns details: 

```bash
sudo -u db_username psql sar
```
```
psql (9.1.9)
Type "help" for help.

sar=# \d notes
                                     Table "public.notes"
   Column   |            Type             |                     Modifiers
------------+-----------------------------+----------------------------------------------------
 id         | integer                     | not null default nextval('notes_id_seq'::regclass)
 title      | character varying(255)      |
 body       | text                        |
 created_at | timestamp without time zone |
 updated_at | timestamp without time zone |
Indexes:
    "notes_pkey" PRIMARY KEY, btree (id)
```

In that case, the Model is a class where I specify also some ActiveRecord validations: 

```ruby
class Note < ActiveRecord::Base
  # connessione a specifico db  
  establish_connection(ENV['SAR_DB_URL'] || \
    'postgres://YOURUSERNAME:YOURPASSWORD@HOSTIPADDRESS/sar')

  # set del nome di una tabella, nel caso in cui non sia fatta con convenzione Rails 
  self.table_name = "notes"

  # validazioni ActiveRecord 
  validates :title, presence: true, length: { minimum: 3 }
  validates :body, presence: true
end 
```

# Install and run

- git clone the source code from github
- install all gems specified in Gemfile, with command: 
    ```bash
    bundle
    ```

- Run the API server in a first terminal
  - set environment variables defining DB URI for both database instances:
   
    ```bash
    export ESAMIANATOMIA_DB_URL=\
    postgres://your-username:your-password@localhost/esamiAnatomia_development
    export SAR_DB_URL=\
    postgres://your-username:your-password@localhost/sar
    ```

  - run the API SERVER daemon, by example in development env, with command: 
    ```shotgun -o localhost```
- Run the API CLIENT calls, using `curl` in a second terminal (below some examples)
- you can monitor/debug ActiveRecord queries running `tux` in a third terminal   

# Client side API call examples

Here below I listed some examples of usage of client-side API calls, using `curl` command line utility. 

## Simplest call

```bash
curl localhost:9393/
```

json 'pretty printed' reply (is sinatra server is running in developement):

```json
{
  "message": "JSON API DEMO (ruby, sinatra, ActiveRecord, postgreSQL)"
}
```

json 'minified' reply (is sinatra server is running in production):

```json
{
  "message":"JSON API DEMO (ruby, sinatra, ActiveRecord, postgreSQL)"
}
```


## Passing parameters in request body

```bash
curl -X POST localhost:9393/login -d '{ "username":"admin", "password":"admin" }'
```

json reply:

```json
{
  "message": "OK: login passed"
}
```


## Authorization token parameter in request header

The example here below show how to manage an Api-key (authorization token).

List of all items of model *users*, passing an _invalid_ key (an UUID, by example):

```bash
curl -X GET http://localhost:9393/users -H "key: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```
json reply:

```json
{
  "message": "sorry, you are not authorized."
}
```


List of all items of model *users*, passing a _valid_ key (let say again an UUID):

```bash
curl -X GET http://localhost:9393/users -H "key: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
```
json reply:

```json
[
  {
    "user": {
      "created_at": "2013-08-27T07:44:48+02:00",
      "crypted_password": ..., 
      "login": "Franco Paperone",
      "role": "docente",
      ...
      "updated_at": "2013-08-27T07:44:48+02:00"
    }
  },
  {
    "user": {
      "created_at": "2013-08-27T07:44:48+02:00",
      "crypted_password": ...,
      "login": "admin",
      "role": "admin",
      .....
      "updated_at": "2013-09-25T22:25:38+02:00"
    }
  }
]
```

## DB RESTful CRUD (Create,  Read, Update, Delete) 

### CREATE of a new record in table *note*:

```bash
curl -X POST http://localhost:9393/notes \
-d '{ "title":"prova", "body":"corpo del messaggio di prova!" }'
```

json reply:

```json
{
  "note": {
    "body": "corpo del messaggio di prova!",
    "created_at": "2013-10-20T11:43:59+02:00",
    "id": 1,
    "title": "prova",
    "updated_at": "2013-10-20T11:43:59+02:00"
  }
}
```

### CREATE of a new record in table *note*:


```
curl -X POST http://localhost:9393/notes -d '{ "title":"pr", "body":"" }'
```
json reply (in case of validation errors):

```json
{
  "title": [
    "is too short (minimum is 3 characters)"
  ],
  "body": [
    "can't be blank"
  ]
}
```


### READ a record from table *note*:

```bash
curl -i http://localhost:9393/notes/1
```
json reply:
```json
{
  "note": {
    "body": "corpo del messaggio di prova!",
    "created_at": "2013-10-20T11:43:59+02:00",
    "id": 1,
    "title": "prova",
    "updated_at": "2013-10-20T11:43:59+02:00"
  }
}
```

### UPDATE a record from table *note*:
```bash
curl -X PUT http://localhost:9393/notes/1 -d '{ "title":"titolo modificato" }'      
```

json reply:
```json
{
  "note": {
    "body": "corpo del messaggio di prova!",
    "created_at": "2013-10-20T11:43:59+02:00",
    "id": 1,
    "title": "titolo modificato",
    "updated_at": "2013-10-20T11:51:54+02:00"
  }
}

```

### DELETE a record from table *note*:
```bash
curl -X DELETE http://localhost:9393/notes/1      
```

### List all records from table `note`:
```bash
curl http://localhost:9393/notes      
```
json reply:
```json
[
  {
    "note": {
      "body": "corpo del messaggio di prova 2!",
      "created_at": "2013-10-20T11:55:33+02:00",
      "id": 2,
      "title": "prova 2",
      "updated_at": "2013-10-20T11:55:33+02:00"
    }
  },
  {
    "note": {
      "body": "corpo del messaggio di prova 3!",
      "created_at": "2013-10-20T11:55:46+02:00",
      "id": 3,
      "title": "prova 3",
      "updated_at": "2013-10-20T11:55:46+02:00"
    }
  }
]
```

## Pagination

Get first page (0), assuming a page contain 10 items, from model `Exam`:

```bash
curl http://localhost:9393/exams/paginate/10/0
```
json reply:
```json
[
  {
    "exam": {
      "id": 1,
      "mail": "selmer.smith@ruelhauck.org",
      "matricola": "974146488",
      ...
      "votoanatomia": "",
      "votoistologia": "24"
    }
  },
  {
    "exam": {
      "id": 2,
      "mail": "waldo@kub.com",
      "matricola": "875086984",
      ...
      "votoanatomia": "",
      "votoistologia": ""
    }
  },
  ...
  ...
  {
    "exam": {
      "id": 10,
      "mail": "marilyne.waelchi@kemmer.name",
      "matricola": "748212641",
      ...
      "votoanatomia": "",
      "votoistologia": "26"
    }
  }
]
```

## File Upload / Download

Upload file `file.txt` and store the file in /public directory:

```bash
curl --upload-file file.txt localhost:9393/upload/
```

Download file `file.txt` stored in /public directory (/public/file.txt):

```bash
curl localhost:9393/download/file.txt
```

## Web Client side API calls using jQuery AJAX 

I wrote a web demo page: [/public/webclient.html] (https://github.com/solyaris/sinatra-api-server-demo/blob/master/public/webclient.html) 
The page allow to test some examples of API methods usage, using jQuery AJAX calls like this one: 

```javascript
$('#notes_post').click(function () {
  $.ajax({
    type: "POST",
    data: JSON.stringify({ title:"nota bla", body: "blablablabla blablablabla" }),
    dataType: "json",
    context: document.body,
    url: url + "/notes",
    success:
      function (data) { $('#reply_notes_post').html( JSON.stringify(data, null, 4)); }
  });
});

```

INSTANT GRATIFICATION: here a screenshot of the "runned" webclient page:
![screenshot](https://raw2.github.com/solyaris/sinatra-api-server-demo/master/public/webclient.html.shot.png)

------

## How to run sinatra server


### Using Shotgun in developement


run shotgun, basic:

```bash
shotgun -o localhost 
```
```== Shotgun/Thin on http://localhost:9393/```


setting environment excipitly: 

```bash
shotgun -o localhost -E development
```

### run server in production

specifying environment, host and port:

```bash
ruby app.rb -o localhost -p 9393 -e production
```
```== Sinatra/1.4.3 has taken the stage on 9393 for production with backup from Thin```


using rackup:

```bash
rackup -o localhost -p 9393 -E production
```
---

## *tux* as an equivalent of *rails console* 

`tux gem`
act as *rails console* for a Sinatra application!
Really useful to query database using ActiveRecord methods.

`hirb gem` 
allow to show (ActiveRecord returned) record data set in pretty print data tables.

Here below some examples using tux interactive console

Run the tux console from command prompt:
```bash
tux
```

Using tux interactive console with Hirb:

```
Loading development environment (Rack 1.2)

>> require 'hirb'
=> true
>> Hirb.enable
=> true

>> Note
=> Note(id: integer, title: string, body: text, created_at: datetime, updated_at: datetime)

>> Note.all
+----+---------+---------------------------------+---------------------------+---------------------------+
| id | title   | body                            | created_at                | updated_at                |
+----+---------+---------------------------------+---------------------------+---------------------------+
| 2  | prova 2 | corpo del messaggio di prova 2! | 2013-10-20 11:55:33 +0200 | 2013-10-20 11:55:33 +0200 |
| 3  | prova 3 | corpo del messaggio di prova 3! | 2013-10-20 11:55:46 +0200 | 2013-10-20 11:55:46 +0200 |
+----+---------+---------------------------------+---------------------------+---------------------------+
2 rows in set
true


>> Exam.select([:id, :cognomenome, :matricola, :updated_at]).order("updated_at DESC").limit(1)
+------+--------------------+-----------+---------------------------+
| id   | cognomenome        | matricola | updated_at                |
+------+--------------------+-----------+---------------------------+
| 1643 | Aaliyah McCullough | 157560384 | 2013-09-25 22:25:38 +0200 |
+------+--------------------+-----------+---------------------------+
1 row in set
true

>> Exam.find_by_sql('SELECT id, cognomenome, matricola FROM exams ORDER BY updated_at DESC LIMIT 5')
+------+------------------------+-----------+
| id   | cognomenome            | matricola |
+------+------------------------+-----------+
| 1643 | Aaliyah McCullough     | 157560384 |
| 1674 | Aaliyah Harvey PhD     | 538093496 |
| 5000 | Marisa Gibson          | 455246174 |
| 4999 | Wilhelmine Stoltenberg | 403257177 |
| 4998 | Hester Rogahn          | 827819282 |
+------+------------------------+-----------+
5 rows in set
true
```

### Hirb tricks

How to see a table row "vertically" (case of many columns), inside tux, using Hirb:

```
>> Hirb.enable :output => {"ActiveRecord::Base" => { :options => {:vertical => true}}}
>> Exam.find(11)
********************* 1. row *********************
            id: 11
   cognomenome: Mr. Oswaldo Willms
     matricola: 513845379
 votoistologia: 30L
 dataistologia: 26-10-2008
  votoanatomia:
  dataanatomia:
  luogonascita: Augustafurt
   datanascita: 14-09-1981
     cellulare: 539943941
          mail: garrison_heel@mcglynngoodwin.org
          note:
       domande: D1:domanda nr. 1
D2:domandina facile
D3: domanda così così
   corsolaurea: Igiene dentale
          sede: Lake Leanne
annoaccademico: 2013
       docente:
          user: Filippo Adinolfi
    created_at: 2013-08-27 07:45:16 +0200
    updated_at: 2013-08-27 07:45:16 +0200
1 row in set
true
>>
```

# Releases

## v.0.1.2
- comments translated in English, adding some explanations. Better explanantion in README, inserting screenshot of Web Client side API calls example using jQuery AJAX.

# Discussion / Todo

- JSON load/dump speed-up: substitute JSON Ruby standard implementation I used, instead using [MultiJson](https://github.com/intridea/multi_json) gem and super-fast [Oj](https://github.com/ohler55/oj) gem. BTW, I used this last approach in my project: [blomming_api](https://github.com/solyaris/blomming_api).

- Insert an example of managing large amount of data with a super-fast in-memory NOSQL database as [Redis](http://redis.io/)!

- better manage HTTP return codes
- better manage error handling
- exceptions handling lack at all.


# Thanks
- Iain Barnett ( https://github.com/yb66 ) for his answer to my stackoverflow.com [accessing-preexistent-database-via-activerecord-about-validations] (http://stackoverflow.com/questions/19402318/sinatra-api-server-accessing-preexistent-database-via-activerecord-about-valida/19461374?noredirect=1#19461374)


# License (MIT)

Copyright (c) 2014 Giorgio Robino

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


# Contact

e-mail: giorgio.robino@gmail.com
