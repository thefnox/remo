return function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local t = require(ReplicatedStorage.DevPackages.t)
	local remote = require(script.Parent.Parent.remote)
	local mockRemotes = require(script.Parent.Parent.utils.mockRemotes)
	local createClientFunction = require(script.Parent.createClientFunction)

	local player: Player = Players.LocalPlayer or {}
	local clientFunction, instance

	beforeEach(function()
		clientFunction = createClientFunction("test", remote(t.string, t.number).returns(t.string))
		instance = mockRemotes.createMockRemoteFunction("test")
	end)

	afterEach(function()
		clientFunction:destroy()
		instance:Destroy()
	end)

	it("should throw when invoked without a handler", function()
		expect(function()
			instance:InvokeClient(player, "", 0)
		end).to.throw()
	end)

	it("should validate incoming argument types", function()
		clientFunction:onInvoke(function()
			return ""
		end)

		expect(function()
			instance:InvokeClient(player, 1, "")
		end).to.throw()

		expect(function()
			instance:InvokeClient(player, "")
		end).to.throw()

		expect(function()
			instance:InvokeClient(player, "", 1)
		end).to.never.throw()
	end)

	it("should validate incoming return types", function()
		instance.OnServerInvoke = function()
			return 1 -- bad return type
		end

		expect(function()
			clientFunction:invoke("", 1):expect()
		end).to.throw()

		instance.OnServerInvoke = function()
			return "" -- good return type
		end

		expect(function()
			clientFunction:invoke("", 1):expect()
		end).to.never.throw()
	end)

	it("should send and receive the correct values", function()
		local player, a, b

		clientFunction:onInvoke(function(...)
			a, b = ...
			return "result"
		end)

		function instance.OnServerInvoke(...)
			player, a, b = ...
			return "result"
		end

		-- incoming invoke
		expect(instance:InvokeClient(player, "test", 1)).to.equal("result")
		expect(player).to.never.be.ok()
		expect(a).to.equal("test")
		expect(b).to.equal(1)

		-- outgoing invoke
		expect(clientFunction:invoke("test2", 2):expect()).to.equal("result")
		expect(player).to.be.ok()
		expect(a).to.equal("test2")
		expect(b).to.equal(2)
	end)

	it("should throw when used after destruction", function()
		clientFunction:onInvoke(function(): () end)
		clientFunction:destroy()

		expect(function()
			clientFunction:invoke("", 1):expect()
		end).to.throw()

		expect(function()
			instance:InvokeClient(player, "", 1)
		end).to.throw()

		expect(function()
			clientFunction:onInvoke(function(): () end)
		end).to.throw()
	end)

	it("should apply the middleware", function()
		local middlewareClientFunction, arg1, arg2, result

		clientFunction = createClientFunction(
			"test",
			remote(t.string, t.number).returns(t.string).middleware(function(next, clientFunction)
				middlewareClientFunction = clientFunction
				return function(...)
					result = next("intercepted", 2)
					return result .. "!"
				end
			end)
		)

		expect(middlewareClientFunction).to.equal(clientFunction)

		clientFunction:onInvoke(function(...)
			arg1, arg2 = ...
			return "result"
		end)

		expect(instance:InvokeClient(player, "test", 1)).to.equal("result!")
		expect(arg1).to.equal("intercepted")
		expect(arg2).to.equal(2)
		expect(result).to.equal("result")
	end)
end
