#!/usr/bin/env bash
# Creates and starts a 3-node MariaDB Galera lab cluster in ./galera-lab
set -e
mkdir -p galera-lab/conf && cd galera-lab
for i in 1 2 3; do cat > conf/node$i.cnf <<EOF
[mysqld]
binlog_format=ROW
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_name=lab_cluster
wsrep_cluster_address=gcomm://node1,node2,node3
wsrep_node_name=node$i
wsrep_node_address=node$i
wsrep_sst_method=mariabackup
wsrep_sst_auth=root:rootpass
EOF
done
cat > docker-compose.yml <<'EOF'
x-node: &node
  image: mirror.gcr.io/library/mariadb:11.4
  environment:
    MARIADB_ROOT_PASSWORD: rootpass
  networks: [galera]
services:
  node1:
    <<: *node
    hostname: node1
    command: --wsrep-new-cluster
    volumes: [./conf/node1.cnf:/etc/mysql/conf.d/galera.cnf:ro, n1:/var/lib/mysql]
    ports: ["3307:3306"]
  node2:
    <<: *node
    hostname: node2
    volumes: [./conf/node2.cnf:/etc/mysql/conf.d/galera.cnf:ro, n2:/var/lib/mysql]
    ports: ["3308:3306"]
    depends_on: [node1]
  node3:
    <<: *node
    hostname: node3
    volumes: [./conf/node3.cnf:/etc/mysql/conf.d/galera.cnf:ro, n3:/var/lib/mysql]
    ports: ["3309:3306"]
    depends_on: [node1]
networks: {galera: {}}
volumes: {n1: {}, n2: {}, n3: {}}
EOF
docker compose up -d node1; echo "Bootstrapping node1..."; sleep 30
docker compose up -d node2; echo "Joining node2..."; sleep 30
docker compose up -d node3; echo "Joining node3..."; sleep 30
docker compose exec node1 mariadb -uroot -prootpass -e "SHOW STATUS LIKE 'wsrep_cluster_size'; SHOW STATUS LIKE 'wsrep_local_state_comment';"
