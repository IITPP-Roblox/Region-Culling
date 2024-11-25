--Simple typed event.
--!strict

local Event = {}
Event.__index = Event

export type Event<T...> = {
    Event: BindableEvent,
} & typeof(setmetatable({}, Event))



--[[
Creates an event.
--]]
function Event.new<T...>(): Event<T...>
    return setmetatable({
        Event = Instance.new("BindableEvent"),
    }, Event) :: Event<T...>
end

--[[
Listens to the event.
--]]
function Event.Connect<T...>(self: Event<T...>, Callback: (T...) -> ()): RBXScriptConnection
    return self.Event.Event:Connect(Callback)
end

--[[
Waits for an event to be fired.
--]]
function Event.Wait<T...>(self: Event<T...>, ...: T...): ()
    return self.Event.Event:Wait(...)
end

--[[
Fires the event listeners.
--]]
function Event.Fire<T...>(self: Event<T...>, ...: T...): ()
    self.Event:Fire(...)
end

--[[
Destroys the event and disconnects all connections.
--]]
function Event.Destroy<T...>(self: Event<T...>): ()
    self.Event:Destroy()
end



return Event