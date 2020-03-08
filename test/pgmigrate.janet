(import tmppg)
(import pq)
(import ../pgmigrate)

(def migrations [
  pgmigrate/uninitialized-migration
  pgmigrate/add-metadata-migration
  @{
    :desc "foobar"
    :uuid "f70f658e-2185-462f-a02a-7396bcb98c72"
    :upgrade
    (fn [conn]
      (eprint "+++ Creating foobar table.")
      (pq/exec conn "create table foobar(a text);"))
    :downgrade 
    (fn [conn]
      (eprint "+++ Dropping foobar table.")
      (pq/exec conn "drop table foobar;"))
  }
])

(with [db (tmppg/tmppg)]
  
  (def conn (pq/connect (db :connect-string)))

  (pgmigrate/migrate
    conn
    migrations
    (pgmigrate/uninitialized-migration :uuid)
    "f70f658e-2185-462f-a02a-7396bcb98c72")

  (pq/exec conn "select * from foobar;")

  (pgmigrate/migrate
    conn
    migrations
    "f70f658e-2185-462f-a02a-7396bcb98c72"
    (pgmigrate/uninitialized-migration :uuid)))