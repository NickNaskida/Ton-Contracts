import "@stdlib/deploy";
import "@stdlib/ownable";

message Bond {
    amount: Int as uint64;
}

message Refund {
    amount: Int as uint64;
    owner: Address;
}

contract BondToken {
    campaign: Address;
    backer: Address;
    donation: Int as uint64;
    refunded: Bool;

    init(campaign: Address, backer: Address) {
        self.campaign = sender();
        self.backer = backer;
        self.donation = 0;
        self.refunded = false;
    }

    receive(msg: Bond) {
        require(self.donation == 0, "Cannot donate twice");
        require(sender() == self.campaign, "Only campaign can donate");
    }

    receive("get fund") {
        require(!self.refunded, "Already refunded");
        self.refunded = true;

        send(SendParameters{
            to: self.campaign,
            value: 0,
            mode: SendBounceIfActionFail,
            body: Refund{amount: self.donation, owner: self.backer}.toCell(),
        });        
    }

    bounced(msg: bounced<Refund>) {
        self.refunded = false;
    }
}

contract CrowdFunding with Deployable, Ownable {
    owner: Address;
    goal: Int as uint64;
    deadline: Int as uint64;

    init(goal: Int, deadline: Int) {
        self.owner = sender();
        self.goal = goal;
        self.deadline = deadline;    
    }

    recieve("donate") {
        require(now() < self.deadline, "Campaign is over");
        let ctx: Context = context();

        let bond: StateInit = initOf BondToken(myAddress(), ctx.sender);

        send(SendParameters{
            to: contractAddress(bond),
            value: 0,
            mode: SendBounceIfActionFail,
            body: Bond{amount: ctx.value}.toCell(),
            code: bond.code,
            data: bond.data
        })
    }

    recieve(msg: Refund) {
        require(now() >= self.deadline, "Campaign is not finished yet");
        require(myBalance() < self.goal);

        let bond: StateInit = initOf BondToken(myAddress(), msg.owner);

        require(sender() == contractAddress(bond), "Only bond can refund");

        require(donation != null, "onlyBacker");

        send(SendParameters{
            to: msg.owner,
            value: msg.amount,
            mode: SendRemainingValue | SendIgnoreErrors
        });
    }

    receive("claim") {
        self.requireOwner();
        require(now() >= self.deadline, "deadline error")
        require(myBalance() >= self.goal, "goal error")

        send(SendParameters{
            to: sender(),
            value: 0, // Set to 0, because we send everything with SendRemainingBalance below
            mode: SendRemainingBalance | SendDestroyIfZero
        })
    }

    get fun campaignDeadline(): Int {
        return self.deadline;
    }

    get fun campaignGoal(): Int {
        return self.goal;
    }

    get fun balance(): Int {
        return myBalance();
    }

    get fun backers(): map<Address, Int as uint64> {
        return self.backers;
    }
}
