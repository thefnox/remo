return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local t = require(ReplicatedStorage.DevPackages.t)
	local remote = require(script.Parent.Parent.remote)
	local mockRemotes = require(script.Parent.Parent.utils.mockRemotes)
	local createClientEvent = require(script.Parent.createClientEvent)

	local clientEvent, instance

	beforeEach(function()
		clientEvent = createClientEvent("test", remote(t.string, t.number))
		instance = mockRemotes.createMockRemoteEvent("test")
	end)

	afterEach(function()
		clientEvent:destroy()
		instance:Destroy()
	end)

	it("should validate incoming argument types", function()
		expect(function()
			instance:FireAllClients(1, "")
		end).to.throw()

		expect(function()
			instance:FireAllClients("")
		end).to.throw()

		expect(function()
			instance:FireAllClients("", 1)
		end).to.never.throw()
	end)

	it("should receive incoming events", function()
		local a, b

		clientEvent:connect(function(...)
			a, b = ...
		end)

		instance:FireAllClients("test", 1)
		expect(a).to.equal("test")
		expect(b).to.equal(1)

		instance:FireAllClients("test2", 2)
		expect(a).to.equal("test2")
		expect(b).to.equal(2)
	end)

	it("should fire outgoing events", function()
		local player, a, b

		instance.OnServerEvent:Connect(function(...)
			player, a, b = ...
		end)

		clientEvent:fire("test", 1)
		expect(player).to.be.ok()
		expect(a).to.equal("test")
		expect(b).to.equal(1)

		clientEvent:fire("test2", 2)
		expect(player).to.be.ok()
		expect(a).to.equal("test2")
		expect(b).to.equal(2)
	end)

	it("should throw when used after destruction", function()
		clientEvent:destroy()

		expect(function()
			clientEvent:fire("test", 1)
		end).to.throw()

		expect(function()
			clientEvent:connect(function() end)
		end).to.throw()
	end)

	it("should not fire disconnected events", function()
		local fired = false
		local disconnect = clientEvent:connect(function()
			fired = true
		end)
		disconnect()
		instance:FireAllClients("intercepted", 1)
		expect(fired).to.equal(false)
	end)

	it("should apply the middleware", function()
		local middlewareClientEvent, arg1, arg2

		clientEvent = createClientEvent(
			"test",
			remote(t.string, t.number).middleware(function(next, clientEvent)
				middlewareClientEvent = clientEvent
				return function(...)
					return next("intercepted", 2)
				end
			end)
		)

		expect(middlewareClientEvent).to.equal(clientEvent)

		clientEvent:connect(function(...)
			arg1, arg2 = ...
		end)

		instance:FireAllClients("test", 1)

		expect(arg1).to.equal("intercepted")
		expect(arg2).to.equal(2)
	end)
end
