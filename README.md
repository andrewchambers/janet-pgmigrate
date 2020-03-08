# pgmigrate

Simple postgres schema management for libpq.

# CLI usage

Create your migration file:

my-migrations.janet
```
(import pq)
(import pgmigrate)

(def migrations [
  # Mandatory migration representing an unintialized database.
  pgmigrate/uninitialized-migration
  
  # Mandatory migration representing an intialized database.
  pgmigrate/add-metadata-migration 
  
  # User defined migrations here...
  @{
    :desc "V1 application schema."
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

```

Next you can query the current database migration, or transition the database schema with --from and --to.

```
$ export PGMIGRATE_CONNECT="host=localhost dbname=postgres"
$ pgmigrate -m my-migrations.janet

Current Migration:
 uuid: e6c12b93-fca8-48d6-8793-47f839b67761
 desc: A boring uninitialized database.
 $ pgmigrate -m my-migrations.janet --from e6c12b93-fca8-48d6-8793-47f839b67761 --to f70f658e-2185-462f-a02a-7396bcb98c72

$ pgmigrate -m my-migrations.janet \
  --from e6c12b93-fca8-48d6-8793-47f839b67761 \
  --to f70f658e-2185-462f-a02a-7396bcb98c72

+++ Creating migration_metadata table.
+++ Creating foobar table

Migrated to:
 uuid: f70f658e-2185-462f-a02a-7396bcb98c72
 desc: V1 application schema.

$ pgmigrate -m my-migrations.janet \
  --from f70f658e-2185-462f-a02a-7396bcb98c72 \
  --to e6c12b93-fca8-48d6-8793-47f839b67761 \
  --downgrade

+++ Dropping foobar table.
+++ Dropping migration_metadata table.

Migrated to:
 uuid: e6c12b93-fca8-48d6-8793-47f839b67761
 desc: A boring uninitialized database.
```