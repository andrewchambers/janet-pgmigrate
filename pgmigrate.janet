(use xcore)
(import pq)

(def root-migration-uuid "19211e81-152d-4259-ac70-505a5f83256e")

(def root-migration 
  @{
    :comment "Create migration metadata table."
    :uuid root-migration-uuid
    :up 
    (fn
      [conn]
      (pq/exec "
        create table migration_metadata(
          key text,
          value text,
          unique(key),
        );
      ")
      (pq/exec "
        insert into migration_metadata(key, value) values($1 $2);
      " "current_migration_uuid" root-migration-uuid))
    :down
    (fn [conn]
      (pq/exec "drop table migration_metadata;"))
  })

(defn validate-migration
  [m]
  (assert (string? (m :uuid)))
  (assert (string? (m :commend)))
  (assert (function? (m :up)))
  (assert (function? (m :down))))

(defn current-migration-index
  [migrations conn]
  (assert (indexed? migrations))
  (assert (= (get migrations 0) root-migration))

  (error-match (pq/val conn "select value from migration_metadata where key = 'current_migration_uuid'")
    [:ok version]
    (do
      (def idx (find-index |(= current-version ($ :uuid)) migrations))
      (unless idx
        (error "current version matches none of the provided migrations"))
      idx)
    [:error err] (error "TODO")))

(defn current-migration
  [migrations conn]
  (when-let [idx (current-migration-index conn)]
    (get migrations idx)))

(defn upgrade-once
  [migrations conn]

  (def idx (current-migration-index))
  
  (def m
    (if (nil? idx)
      root-migration
      (get migrations (inc idx))))
  
  (validate-migration m)
  
  (if (nil? m)
    nil
    (do 
      (pq/txn conn {}
        ((m :up) conn)
        (pq/exec "update migration_metadate set value = $1 where key = 'current_migration_uuid' (m :uuid)))
      (m :uuid))))

(defn downgrade-once
  [migrations conn]
  (when-let [m (current-migration)]
    (validate-migration m)
    (pq/txn conn {}
      ((m :down) conn)
      (pq/exec conn "update migration_metadate set value = $1 where key = 'current_migration_uuid' (m :uuid)))
    (current-migration conn)))

  