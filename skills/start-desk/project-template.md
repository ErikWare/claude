## Desk

<!-- Written by /start-desk. The kit's scripts and boot file read these values;
     edit them here, never in the scripts. -->

| key | value |
|---|---|
| trunk | `{{TRUNK}}` |
| slot pattern | `{{SLOT_PATTERN}}` |
| slot folders | {{SLOTS}} |
| in-flight ceiling | 3 — review bandwidth, not folders; the one number no project raises |
| backlog | `{{BACKLOG}}` |
| desk log | `{{DESK_LOG}}` |
| briefs | `docs/briefs/<ID>.md` — dispatched by path, deleted when the branch lands |
| test command | `{{TEST_CMD}}` |
| per-claim setup | `{{SETUP_CMD}}` |
| push after landing | {{PUSH}} |

**Landing** (desk, main checkout):

```sh
~/.claude/kit/scripts/land.sh {{TRUNK}} wt/<topic> '{{GATE_CMD}}' <owned paths...>
```

**Gates that run on every landing**, inside the test command above:
`~/.claude/kit/scripts/gates.sh ids {{BACKLOG}}`. Before assigning a new ID,
run `gates.sh ids-refs {{BACKLOG}} {{TRUNK}}`: a collision between two
unlanded branches can't be seen from any single tree.
