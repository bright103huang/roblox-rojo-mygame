local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local AnimationFactory = {}

local function createPose(partName, cframe, weight)
    local pose = Instance.new("Pose")
    pose.Name = partName
    pose.CFrame = cframe
    pose.Weight = weight or 1
    return pose
end

local function createKeyframe(time, poses)
    local kf = Instance.new("Keyframe")
    kf.Time = time
    for _, pose in ipairs(poses) do
        pose.Parent = kf
    end
    return kf
end

function AnimationFactory:CreateSitSequence()
    local seq = Instance.new("KeyframeSequence")
    seq.Name = "SitCrossLegged"
    local kf0 = createKeyframe(0, {
        createPose("LeftUpperLeg", CFrame.Angles(-0.8, 0.3, 0)),
        createPose("RightUpperLeg", CFrame.Angles(-0.8, -0.3, 0)),
        createPose("HumanoidRootPart", CFrame.new(0, -1.2, 0)),
    })
    kf0.Parent = seq
    local kf1 = createKeyframe(0.3, {
        createPose("LeftUpperLeg", CFrame.Angles(-0.8, 0.3, 0)),
        createPose("RightUpperLeg", CFrame.Angles(-0.8, -0.3, 0)),
        createPose("LeftLowerLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("RightLowerLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("LeftFoot", CFrame.new(0, 0, 0.3)),
        createPose("RightFoot", CFrame.new(0, 0, -0.3)),
        createPose("LowerTorso", CFrame.Angles(0, 0, -0.1)),
        createPose("HumanoidRootPart", CFrame.new(0, -1.2, 0)),
    })
    kf1.Parent = seq
    return seq
end

function AnimationFactory:CreateLaySequence()
    local seq = Instance.new("KeyframeSequence")
    seq.Name = "LayDown"
    local rot = math.rad(-90)
    local kf0 = createKeyframe(0, {})
    kf0.Parent = seq
    local kf1 = createKeyframe(0.5, {
        createPose("HumanoidRootPart", CFrame.Angles(0, 0, rot)),
        createPose("UpperTorso", CFrame.Angles(0, 0, rot)),
        createPose("LowerTorso", CFrame.Angles(0, 0, rot)),
        createPose("LeftUpperArm", CFrame.Angles(0, 0, 0.2)),
        createPose("RightUpperArm", CFrame.Angles(0, 0, -0.2)),
    })
    kf1.Parent = seq
    return seq
end

function AnimationFactory:CreateKneelSequence()
    local seq = Instance.new("KeyframeSequence")
    seq.Name = "KneelBow"
    local kf0 = createKeyframe(0, {})
    kf0.Parent = seq
    local kf1 = createKeyframe(0.3, {
        createPose("HumanoidRootPart", CFrame.new(0, -1, 0)),
        createPose("LeftUpperLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("RightUpperLeg", CFrame.Angles(1.2, 0, 0)),
    })
    kf1.Parent = seq
    local kf2 = createKeyframe(0.6, {
        createPose("HumanoidRootPart", CFrame.new(0, -1, 0)),
        createPose("LeftUpperLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("RightUpperLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("UpperTorso", CFrame.Angles(math.rad(30), 0, 0)),
    })
    kf2.Parent = seq
    local kf3 = createKeyframe(1.0, {
        createPose("HumanoidRootPart", CFrame.new(0, -1, 0)),
        createPose("LeftUpperLeg", CFrame.Angles(1.2, 0, 0)),
        createPose("RightUpperLeg", CFrame.Angles(1.2, 0, 0)),
    })
    kf3.Parent = seq
    return seq
end

function AnimationFactory:PlayAnimation(humanoid, sequence, looped)
    if sequence.ClassName == "KeyframeSequence" then
        local anim = Instance.new("Animation")
        anim.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
        sequence = anim
    end
    local track = humanoid:LoadAnimation(sequence)
    track.Priority = Enum.AnimationPriority.Action
    track.Looped = looped or false
    track:Play(0.1, 1, 1)
    return track
end

return AnimationFactory
