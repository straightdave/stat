# stat
Simple Statistic Solution

## Overview

Two apps:
* server
* client (library)

Also,
* Queue (Redis, etc.)
* Permanent data storage (Postgres, etc.)

## Data Pipeline

```
                                  +-------+
App (client) ---> StatServer ---> |       |                   +-----+
                                  |       |                   |     |
App (client) ---> StatServer ---> | Queue | ---> Merging ---> | DB  |
                                  |       |    (scheduled)    |     |
App (client) ---> StatServer ---> |       |                   +-----+
                                  +-------+
```

## Data Facet

Example: concurrent users of a certain GROUP, a TEAM, a SERVER, etc.
It can be expressed as:
* concurrent_user (no facet)
* concurrent_user.group.X
* concurrent_user.team.Y
* concurrent_user.server.Z
etc.

## Artifact

### Stat Client

**Goal**
* Cache user events
* Periodically do aggregation
* Send data to Server

### Stat Server

**Goal**
* Receive and cache data from Clients
* Periodically enqueue the combined data
* Scheduled job:
  - pop data of a fixed time interval (basic interval) from the queue
  - do aggregation
  - save result (now it's called a sample) to permanent storage
