import iterm2
import asyncio

async def main(connection):
    app = await iterm2.async_get_app(connection)
    window = app.current_terminal_window
    
    if window is not None:
        tab = window.current_tab
        session = tab.current_session
        
        grid_size = session.grid_size
        total_width = grid_size.width
        total_height = grid_size.height
        
        right_session = await session.async_split_pane(vertical=True, before=False)
        
        bottom_right_session = await right_session.async_split_pane(vertical=False, before=False)
        
        session.preferred_size = iterm2.util.Size(int(total_width * 0.55), total_height)
        
        right_session.preferred_size = iterm2.util.Size(int(total_width * 0.45), int(total_height * 0.55))
        
        bottom_right_session.preferred_size = iterm2.util.Size(int(total_width * 0.5), int(total_height * 0.45))
        
        await tab.async_update_layout()
        
        await right_session.async_send_text('btop\n')
        
        await session.async_activate()
    else:
        print("No active iTerm2 window")

if __name__ == "__main__":
    try:
        asyncio.get_event_loop()
    except RuntimeError:
        asyncio.set_event_loop(asyncio.new_event_loop())
    
    iterm2.run_until_complete(main)
