(declare-project
  :name "pgmigrate"
  :author "Andrew Chambers"
  :license "MIT"
  :url "https://github.com/andrewchambers/janet-pgmigrate"
  :repo "git+https://github.com/andrewchambers/janet-pgmigrate.git")

(declare-source
  :name "pgmigrate"
  :source ["pgmigrate.janet"])

(declare-binscript
  :main "pgmigrate")
