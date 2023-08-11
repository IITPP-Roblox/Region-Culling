--[[
TheNexusAvenger

Simple typed event.
--]]
--!strict

local Event = {}
Event.__index = Event

export type Event<T...> = {
    Event: BindableEvent,
    
    new: () -> (Event<T...>),
    Connect: (self: Event<T...>, Callback: (T...) -> ()) -> (RBXScriptConnection),
    Wait: (self: Event<T...>) -> (T...),
    Fire: (self: Event<T...>, T...) -> (),
    Destroy: (self: Event<T...>) -> (),
}



--[[
Creates an event.
--]]
function Event.new<T...>(): Event<T...>
    return setmetatable({
        Event = Instance.new("BindableEvent"),
    } :: any, Event) :: Event<T...>
end

--[[
Listens to the event.
--]]
function Event:Connect<T...>(Callback: (T...) -> ()): RBXScriptConnection
    return self.Event.Event:Connect(Callback :: any)
end

--[[
Waits for an event to be fired.
--]]
function Event:Wait<T...>(...: T...): ()
    return self.Event.Event:Wait(...)
end

--[[
Fires the event listeners.
--]]
function Event:Fire<T...>(...: T...): ()
    self.Event:Fire(...)
end

--[[
Destroys the event and disconnects all connections.
--]]
function Event:Destroy<T...>(): ()
    self.Event:Destroy()
end



return Event