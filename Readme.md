
<img src="./logo.png" width="360"  align="right">

### DISCLAIMER ###

The plugin is being used to develop a Game but it isnt feature complete yet. 
To get started there is a Third Person Template implementation in NimForUE: https://github.com/jmgomez/NimTemplate


### Roadmap ###

https://github.com/jmgomez/NimForUE/wiki/Roadmap

### Why NimForUE?

The core idea is to have a short feedback loop while having native performance and a modern language that can access all features Unreal provides. 

The plugin outputs native dynamic libraries (DLLs) that are hooked into UnrealEngine. 

The design philosophy is to not change any unreal conventions on the API side of things, so anyone that knows Unreal can reuse its knowledge. The code guidelines follow (for the most part) the Nim conventions when not in contradiction with the Unreal ones. 

If you have any question or wants to know more and follow the updates:
 
[Join us on the Discord group](https://discord.gg/smD8vZxzHh)

If you dont have Discord, you can also reach out at:

[Twitter](https://twitter.com/_jmgomez_)


### Why Nim?


Nim is fast and easy to read with a good type system and a fantastic macro system, and it also has the best C++ interop in the industry. 

The compiler is incredibly fast, and it's about to get faster with incremental compilation. 

The performance is the same as with C++ because you are outputting C++ with no overhead (no C types sitting in the middle that you would require with a language like Rust). 

Fully control the memory if you so desire (including move semantics). 

Nim Type System has everything (and probably more) that you can expect from a typed lang: generics, sum types, constraints on those, and it even has C++-like concepts (my personal favorite feature from C++).

The macro system is outstanding. Just to give you an idea, await/async are implemented as a library. The same applies to Pattern Matching. This means (as you will see below) that you can create *typed* DSLs for your Unreal Projects that use the semantics that you want.




### NimForUE 101 Playlist:
[![NimForUE 101 Playlist](https://img.youtube.com/vi/j6N6WGt2lO0/0.jpg)](https://www.youtube.com/watch?v=NuB_PjxVisw&list=PL_l806S1qgBLfGDn9khLMPFLE0k03ARoF)



### Showcase at NimConf 2022:
[![Showcase at NimConf 2022](https://img.youtube.com/vi/0b3ixaz2uOg/0.jpg)](https://youtu.be/0b3ixaz2uOg)



### Showcase GameFromScratch
[![Showcase GameFromScratch](https://img.youtube.com/vi/Cdr4-cOsAWA/0.jpg)](https://youtu.be/Cdr4-cOsAWA)




### Inspiration 

The major inspiration is the previous NimUE plugin but NimForUE uses a radically different approach. Instead of generating C++ code, it generates a dynamic library. This allows us to use a debugger and to have quite fast hot reloading. We also plan to rely on Unreal's reflection system to automatically bind exposed APIs.

We also got inspiration from the AngelScript plugin. What we like about it is how it sits on top of C++ and allows for generating Blueprint classes and functions in Editor time. We hope to not modify the Engine's sources to accomplish this. 

There are more plugins out there that inspired us, (Unreal.clr, Unreal.js.. etc.). The major differentiator factor, apart from the one mentioned above, is that we don't rely on any kind of virtual machine.




## Examples
The whole Cpp ThirdPersonTemplate in Nim would be like this:

```nim


uClass ANimCharacter of ACharacter:
  (config=Game)
  uprops(EditAnywhere, BlueprintReadOnly, DefaultComponent, Category = Camera):
    cameraBoom : USpringArmComponentPtr 
  uprops(EditAnywhere, BlueprintReadOnly, DefaultComponent, Attach=(cameraBoom, SpringEndpoint), Category = Camera):
    followCamera : UCameraComponentPtr
  uprops(EditAnywhere, BlueprintReadOnly, Category = Input):
    defaultMappingContext : UInputMappingContextPtr
    (jumpAction, moveAction, lookAction) : UInputActionPtr

  defaults: # default values for properties on the cdo
    capsuleComponent.capsuleRadius = 40
    capsuleComponent.capsuleHalfHeight = 96
    bUseControllerRotationYaw = false
    characterMovement.jumpZVelocity = 700
    characterMovement.airControl = 0.35
    characterMovement.maxWalkSpeed = 500
    characterMovement.minAnalogWalkSpeed = 20
    characterMovement.brakingDecelerationWalking = 2000
    characterMovement.bOrientRotationToMovement = true
    cameraBoom.targetArmLength = 400
    cameraBoom.busePawnControlRotation = true
    followCamera.bUsePawnControlRotation = true
  
  override: #Notice here we are overriding a native cpp virtual func. You can call `super` self.super(playerInputComponent) or super(self, playerInputComponent)
    proc setupPlayerInputComponent(playerInputComponent : UInputComponentPtr) = 
      let pc = ueCast[APlayerController](self.getController())
      if pc.isNotNil():
        let inputComponent = ueCast[UEnhancedInputComponent](playerInputComponent)
        let subsystem = getSubsystem[UEnhancedInputLocalPlayerSubsystem](pc).get()
        subsystem.addMappingContext(self.defaultMappingContext, 0)
        inputComponent.bindAction(self.jumpAction, ETriggerEvent.Triggered, self, n"jump")
        inputComponent.bindAction(self.jumpAction, ETriggerEvent.Completed, self, n"stopJumping")
        inputComponent.bindAction(self.moveAction, ETriggerEvent.Triggered, self, n"move")
        inputComponent.bindAction(self.lookAction, ETriggerEvent.Triggered, self, n"look")

  
  ufuncs:
    proc move(value: FInputActionValue) = 
      let 
        movementVector = value.axis2D()
        rot = self.getControlRotation()
        rightDir = FRotator(roll: rot.roll, yaw: rot.yaw).getRightVector()
        forwardDir = FRotator(yaw: rot.yaw).getForwardVector()
      self.addMovementInput(rightDir, movementVector.x, false) 
      self.addMovementInput(forwardDir, movementVector.y, false) 

    proc look(value: FInputActionValue) =
      let lookAxis = value.axis2D()
      self.addControllerYawInput(lookAxis.x)
      self.addControllerPitchInput(lookAxis.y)

uClass ANimGameMode of AGameModeBase:
  proc constructor(init:FObjectInitializer) = #Similar to default but allows you to write full nim code
    let classFinder = makeClassFinder[ACharacter]("/Game/ThirdPerson/Blueprints/BP_ThirdPersonCharacter")
    self.defaultPawnClass = classFinder.class


```



This code can be found at src/examples/actorexample. There are more examples inside that folder. You can do `import examples/example` in from Game.nim (see the NimTemplate) to play with it. 
```nim
#Nim UClasses can derive from the same classes that blueprints can derive from.

uClass AExampleActor of AActor:
    (BlueprintType, Blueprintable) #Class specifiers follow the C++ convention. 
    uprops(EditAnywhere, BlueprintReadWrite): #you can declare multiple UPROPERTIES in one block
        exampleValue : FString #They are declare as nim properties. 
        anotherVale : int #notice int in nim is int64. while in c++ it is int32.
        anotherValueInt32 : int32 #this would be equivalent to int32
        predValue : FString = "Hello" #you can assign a default value to a property.
        predValueInt : int =  20 + 10 #you can even use functions (the execution is deferred)
        nameTest : FString = self.getName() #you can even use functions within the actor itself. It is accessible via this or self.

#In general when using the equal symbol in a uClass declaration, a default constructor will be generated.
#you can specify a custom constructor if you want to by defining a regular nim function and adding the pragma uconstructor

proc myExampleActorCostructor(self: AExampleActorPtr, initializer: FObjectInitializer) {.uConstructor.} =
    UE_Log "The constructor is called for the actor"
    self.anotherVale = 5
    #you can override the values set by the default constructor too since they are added adhoc before this constructor is called.
    self.predValue = "Hello World"

#Notice that you rarelly will need to define a custom constructor for your class. Since the CDO can be set within the DSL. 

#UFunctions

#UFunctions can be added by adding the pragma uFunc, and for each meata, another pragma:
#Since in nim functions are separated from the type they are declared in, you need to specify the type as the first argument.

proc myUFunction(self: AExampleActorPtr, param : FString) : int32 {. ufunc, BlueprintCallable .} = 
    UE_Log "UFunction called"
    5

#You can also use the uFunctions macro to declare multiple uFunctions at once. The preferred way is still to use them in an uClass block like shown above.
uFunctions:
    (BlueprintCallable, self:AExampleActorPtr) #you must specify the type and any shared meta like this.

    proc anotherUFunction(param : FString) : int32 = 10 #now you can define the function as you normally would.
    proc yetAnotherUFunction(param : FString) : FString = 
        self.getName() #you can access to the actor itself by the name you specify in the uFunctions macro.
    
    proc customPragma(param : FString) : int32 {. BlueprintPure .} = 10 #you can also specify custom pragmas per functions rather than creating a new block

    proc callFromTheEditor() {. CallInEditor .} = 
        UE_Log "Call from the editor"
        
```
Which produces:
![Blueprint](https://media.discordapp.net/attachments/844939530913054752/1004338096160120913/unknown.png)

## Troubleshooting 

#### '...\NimTemplate\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUE\PCH.NimForUE.h.pch' precompiled header file is from a different version of the compiler, or the precompiled header is C++ and you are using it from C (or vice versa)`

This erros means that the vs tools is using a different compiler version to compile the Nim Dll and the Unreal plugin. You need to place this file 

BuildConfiguration.xml

```xml
<?xml version="1.0" encoding="utf-8" ?>
<Configuration xmlns="https://www.unrealengine.com/BuildConfiguration">
    <WindowsPlatform>
        <CompilerVersion>14.34.31933</CompilerVersion>
        <Compiler>VisualStudio2022</Compiler>
    </WindowsPlatform>
</Configuration>
```

In one of the Unreal recommend path. See https://docs.unrealengine.com/4.27/en-US/ProductionPipelines/BuildTools/UnrealBuildTool/BuildConfiguration/ for more information. The compiler version may vary on what you have in your vc toolchain. The Nim compiler picks the latest, you can see the unreal version in the generated `compiler_version.txt` in the NimForUE plugin directory. 

Kudos to Mike from https://gamefromscratch.com/ for reporting and support on troubleshoot it. We are also working in a patch so the next version of the Nim compiler tooling (vcc) can work with a specific version of the c++ compiler via an argument so we dont have to specify the version on the UBT side of things.

