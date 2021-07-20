# Testing parent/child, remove before merging

curl -X PUT localhost:9206/quiz?pretty=true -H 'Content-Type: application/json' -d  @- <<'EOF'
{
  "mappings": {
    "question": {
      "properties": {
        "id_field": {
          "type": "keyword"
        },
        "content": {
          "type": "text"
        },
        "comment_type": {
          "type": "join",
          "relations": {
            "question": "answer"
          }
        }
      }
    }
  }
}
EOF

curl -X PUT localhost:9206/quiz/_doc/1?pretty=true -H 'Content-Type: application/json' -d  @- <<'EOF'
{
  "id_field": "1",
  "content": "2+3?",
  "comment_type": "question"
}
EOF

curl -X PUT localhost:9206/quiz/_doc/2?pretty=true -H 'Content-Type: application/json' -d  @- <<'EOF'
{
  "id_field": "2",
  "content": "3+4?",
  "comment_type": "question"
}
EOF


curl -X PUT 'localhost:9206/quiz/_doc/3?routing=1&pretty=true' -H 'Content-Type: application/json' -d  @- <<'EOF'
{
  "id_field": "3",
  "content": "3!",
  "comment_type": {
    "name": "answer",
    "parent": "1"
  }
}
EOF


curl -X PUT 'localhost:9206/quiz/_doc/4?routing=1&pretty=true' -H 'Content-Type: application/json' -d  @- <<'EOF'
{
  "id_field": "4",
  "content": "4!",
  "comment_type": {
    "name": "answer",
    "parent": "1"
  }

}
EOF

# fails with
#          "type" : "document_missing_exception",
#          "reason" : "[question][3]: document missing",
curl -X POST 'localhost:9206/_bulk/?pretty=true' -H 'Content-Type: application/json' -d  '
{ "update": { "_id": "3", "_index": "quiz", "_type": "question" }  }
{ "doc": { "content": "Changed answer!" } }
{ "create": { "_id": "5", "_index": "quiz", "_type": "question" }  }
{ "doc": { "content": "New answer!", "comment_type": { "name": "answer", "parent": "1" } } }
'

# works
curl -X POST 'localhost:9206/_bulk/?pretty=true' -H 'Content-Type: application/json' -d  '
{ "update": { "_id": "3", "_index": "quiz", "_type": "question" }  }
{ "doc": { "content": "Changed answer!", "comment_type": { "name": "answer", "parent": "1" } } }
{ "create": { "_id": "5", "_index": "quiz", "_type": "question" }  }
{ "doc": { "content": "New answer!", "comment_type": { "name": "answer", "parent": "1" } } }
'

curl -X POST 'localhost:9206/_bulk/?pretty=true' -H 'Content-Type: application/json' -d  '
{ "delete": { "_id": "3", "_index": "quiz", "_type": "question" }  }
'
# fails with (?)
#{
#  "took" : 3,
#  "errors" : false,
#  "items" : [
#    {
#      "delete" : {
#        "_index" : "quiz",
#        "_type" : "question",
#        "_id" : "3",
#        "_version" : 2,
#        "result" : "not_found",
#        "_shards" : {
#          "total" : 2,
#          "successful" : 1,
#          "failed" : 0
#        },
#        "_seq_no" : 1,
#        "_primary_term" : 2,
#        "status" : 404
#      }
#    }
#  ]
#}


curl -X POST 'localhost:9206/_bulk/?pretty=true' -H 'Content-Type: application/json' -d  '
{ "delete": { "_id": "3", "_index": "quiz", "_type": "question", "parent": "1" }  }
'
# works!
