-- ROBLOX upstream: https://github.com/apollographql/apollo-client/blob/v3.4.2/src/utilities/observables/__tests__/Observable.ts
return function()

	-- ROBLOX deviation: tests don't apply / module is just re-exporting files
	--[[Original tests
	describe("Observable", function()
		describe("subclassing by non-class constructor functions", function()
			it('simulating super(sub) with Observable.call(this, sub)', () => {
    		  function SubclassWithSuperCall<T>(sub: Subscriber<T>) {
    		    const self = Observable.call(this, sub) || this;
    		    self.sub = sub;
    		    return self;
    		  }
    		  return check(newify(SubclassWithSuperCall));
    		});

    		it('simulating super(sub) with Observable.apply(this, arguments)', () => {
    		  function SubclassWithSuperApplyArgs<T>(_sub: Subscriber<T>) {
    		    const self = Observable.apply(this, arguments) || this;
    		    self.sub = _sub;
    		    return self;
    		  }
    		  return check(newify(SubclassWithSuperApplyArgs));
    		});

    		it('simulating super(sub) with Observable.apply(this, [sub])', () => {
    		  function SubclassWithSuperApplyArray<T>(...args: [Subscriber<T>]) {
    		    const self = Observable.apply(this, args) || this;
    		    self.sub = args[0];
    		    return self;
    		  }
    		  return check(newify(SubclassWithSuperApplyArray));
    		});
	
		end)
	end)
]]
end
