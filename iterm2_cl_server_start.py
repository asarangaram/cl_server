#!/usr/bin/env python3

import iterm2

DIR = "/Users/anandasarangaram/Work/github/cl_server"


# ┌─────────────────────────────┬───────────────────────────────────────────────┐
# │                             │               1.  vector store                │
# │                             ├───────────────────────────────────────────────┤
# │                             │               2. mqtt                         │
# │                             ├───────────────────────────────────────────────┤
# │         0 claude            │              3. authentication                │
# │                             ├───────────────────────────────────────────────┤
# │                             │              4. media_store                   │
# │                             ├───────────────────────┬───────────────────────┤
# │                             │ 5. inference          |    6. infer worker    │
# └─────────────────────────────┴───────────────────────┴───────────────────────┘
async def main(connection):

    app = await iterm2.app.async_get_app(connection)

    window = await iterm2.Window.async_create(connection)
    session0 = window.tabs[0].sessions[0]

    await session0.async_send_text(f"cd {DIR} && echo start claude here\n")

    session1 = await session0.async_split_pane(vertical=True)
    await session1.async_send_text(
        f"cd {DIR}/services/vector_store_qdrant && ./bin/vector_store_start\n"
    )

    session2 = await session1.async_split_pane(vertical=False)
    await session2.async_send_text(
        f"cd {DIR}/services/mqtt_broker && ./bin/mqtt_broker_start\n"
    )

    session3 = await session2.async_split_pane(vertical=False)
    await session3.async_send_text(f"cd {DIR}/services/authentication && ./start.sh\n")

    session4 = await session3.async_split_pane(vertical=False)
    await session4.async_send_text(f"cd {DIR}/services/media_store && ./start.sh\n")

    session5 = await session4.async_split_pane(vertical=False)
    await session5.async_send_text(f"cd {DIR}/services/inference && ./start.sh\n")

    session6 = await session5.async_split_pane(vertical=True)
    await session6.async_send_text(f"cd {DIR}/services/inference && ./worker.sh\n")

    session7 = await session0.async_split_pane(vertical=False, size=0.30)
    await session7.async_send_text(f"cd {DIR} && ./monitor_services.sh\n")


iterm2.run_until_complete(main)
