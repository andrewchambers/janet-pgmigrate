(use xcore)
(import pq)

(def uninitialized-migration
 @{
    :desc "A boring uninitialized database."
    :uuid "e6c12b93-fca8-48d6-8793-47f839b67761"
    :upgrade
      (fn [conn] (error "cannot apply the null migration"))
    :downgrade
      (fn [conn] nil)
  })

(def add-metadata-migration 
  @{
    :desc "Database with a migration metadata table."
    :uuid "19211e81-152d-4259-ac70-505a5f83256e"
    :upgrade 
      (fn
        [conn]
        (eprint "+++ Creating migration_metadata table.")
        (pq/exec conn "
          create table migration_metadata(
            key text,
            value text,
            unique(key)
          );
        ")
        # Insert an empty uuid, this will be overwritten with an update.
        (pq/exec conn "
          insert into migration_metadata(key, value) values('current_migration_uuid', '');
        "))
    :downgrade
      (fn [conn]
        (eprint "+++ Dropping migration_metadata table.")
        (pq/exec conn "drop table migration_metadata;"))
  })

(defn- migration-metadata-table-exists?
  [conn]
  (pq/val conn
    "select exists
      (select from information_schema.tables
       where table_schema = current_schema() 
         and table_name = 'migration_metadata');"))

(defn- migration-uuid-to-idx
  [migrations uuid]
  (find-index |(= uuid ($ :uuid)) migrations))

(defn- current-migration-index
  [conn migrations]
  (if (migration-metadata-table-exists? conn)
    (let [uuid (pq/val conn "select value from migration_metadata where key = 'current_migration_uuid'")]
      (unless uuid
        (error "migration table should have a migration uuid"))
      (def idx (migration-uuid-to-idx migrations uuid))
      (unless idx
        (error "current uuid matches none of the provided migrations"))
      idx)

    0))

(defn current-migration
  [conn migrations]
  (when-let [idx (current-migration-index conn migrations)]
    (get migrations idx)))

(defn- upgrade-once
  [conn migrations]
  (pq/txn conn {}
    (def idx (current-migration-index conn migrations))
    (def next-m (get migrations (inc idx)))
    (if next-m
      (do
        ((next-m :upgrade) conn)
        (pq/exec conn "update migration_metadata set value = $1 where key = 'current_migration_uuid';" (next-m :uuid))
        next-m))
      (current-migration conn migrations)))

(defn- downgrade-once
  [conn migrations]
  (pq/txn conn {}
    (def idx (current-migration-index conn migrations))
    (def m (get migrations idx))
    (when-let [prev-m (get migrations (dec idx) uninitialized-migration)]
      ((m :downgrade) conn)
      (when (migration-metadata-table-exists? conn)
        (pq/exec conn
          "update migration_metadata set value = $1 where key = 'current_migration_uuid';"
          (prev-m :uuid))))
      (current-migration conn migrations)))

(defn- valid-migration?
  [m]
  (and (= (length m) 4)
   (string? (m :uuid))
   (string? (m :desc))
   (function? (m :upgrade))
   (function? (m :downgrade))))

(defn migrate
  [conn migrations from-uuid to-uuid &opt confirm-cb]
  
  (unless (indexed? migrations)
    (error "migrations must be an array or tuple"))

  (unless (all valid-migration? migrations)
    (error "malformed migration in input"))

  (unless (= (length migrations)
            (length (distinct (map |($ :uuid) migrations))))
    (error "all migrations must have unique uuids"))

  (unless migrations
    (error "migration module must export 'migrations"))
  (unless (indexed? migrations)
    (error "migrations must be an array or tuple."))
  (unless (and (= (get migrations 0) uninitialized-migration)
               (= (get migrations 1) add-metadata-migration))
    (error "migrations must begin with pgmigrate/uninitialized-migration and pgmigrate/add-metadata-migration"))

  (default confirm-cb (fn [&] true))

  (var current-m (current-migration conn migrations))

  (unless (= from-uuid (current-m :uuid))
    (error
      (string/format "from uuid does not match the current migration uuid: %v desc: %v"
        (current-m :uuid)
        (current-m :desc))))

  (def from-idx (migration-uuid-to-idx migrations from-uuid))
  (def to-idx (migration-uuid-to-idx migrations to-uuid))

  (unless from-idx
    (error "specified from uuid matches no migration uuids"))
  
  (unless to-idx
    (error "specified to uuid matches no migration uuids"))
  
  (when (confirm-cb from-idx to-idx)

    (def n (- to-idx from-idx))
    (def [n action action-desc]
      (if (<= 0 n)
        [n upgrade-once "upgrade"]
        [(- n) downgrade-once "downgrade"]))
    
    (loop [_ :range [0 n]]
      (set current-m (action conn migrations)))

    current-m))

# repl helpers
# (def migrations [uninitialized-migration add-metadata-migration])
# (def conn (pq/connect "host=localhost dbname=postgres"))
# (current-migration-index conn migrations)
# (current-migration conn migrations)
# (upgrade-once conn migrations)
# (downgrade-once conn migrations)
# (pq/all conn "select * from migration_metadata;")
