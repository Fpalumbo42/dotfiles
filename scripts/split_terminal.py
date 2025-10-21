#!/usr/bin/env python3
# Script pour diviser iTerm2 en 3 volets avec btop

import iterm2
import asyncio

async def main(connection):
    app = await iterm2.async_get_app(connection)
    window = app.current_terminal_window
    
    if window is not None:
        # Get the current session
        session = window.current_tab.current_session
        
        # Split vertically (left and right) - 60/40 split
        right_session = await session.async_split_pane(vertical=True, before=False)
        
        # Split the right pane horizontally (top and bottom) - 50/50 split
        bottom_right_session = await right_session.async_split_pane(vertical=False, before=False)
        
        # Run btop in the top right pane (beautiful system monitor)
        await right_session.async_send_text('btop\n')
        
        # Focus on the left pane (main working area)
        await session.async_activate()
    else:
        print("❌ Pas de fenêtre iTerm2 active")

if __name__ == "__main__":
    iterm2.run_until_complete(main)
