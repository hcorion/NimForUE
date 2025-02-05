##This file is temp until we move the uobjectflags into models
##There is a cycle between uemeta (were it initialized lived) and uebind via nimforue.nim. 
##The solution is to allow uobjectflags in models but then we need to get rid of 
import ../unreal/coreuobject/uobjectflags
import models
import std/[sugar, tables, options, sequtils]
import ../codegen/modulerules




#UE META CONSTRUCTORS. Noticuee they are here because they pull type definitions from Cpp which cant be loaded in the ScriptVM
func makeFieldAsUProp*(name, uPropType, typeName: string, flags = CPF_None, metas: seq[UEMetadata] = @[], size: int32 = 0, offset: int32 = 0): UEField =
  UEField(kind: uefProp, name: name, uePropType: uPropType, typeName:typeName, propFlags: EPropertyFlagsVal(flags), metadata: metas, size: size, offset: offset)

func makeFieldAsUPropMulDel*(name, uPropType, typeName: string, flags = CPF_None, metas: seq[UEMetadata] = @[]): UEField =
  UEField(kind: uefProp, name: name, uePropType: uPropType, typeName:typeName, propFlags: EPropertyFlagsVal(flags), metadata: @[makeUEMetadata(MulticastDelegateMetadataKey)]&metas)

func makeFieldAsUPropDel*(name, uPropType, typeName: string, flags = CPF_None, metas: seq[UEMetadata] = @[]): UEField =
  UEField(kind: uefProp, name: name, uePropType: uPropType, typeName:typeName, propFlags: EPropertyFlagsVal(flags), metadata: @[makeUEMetadata(DelegateMetadataKey)]&metas)


func makeFieldAsUFun*(name : string, signature: seq[UEField], typeName: string, flags = FUNC_None, metadata: seq[UEMetadata] = @[]): UEField =
  UEField(kind: uefFunction, name: name, typeName: typeName, signature: signature, fnFlags: EFunctionFlagsVal(flags), metadata: metadata, actualFunctionName: name)

func makeFieldAsUPropParam*(name, uPropType, typeName: string, flags = CPF_Parm): UEField =
  UEField(kind: uefProp, name: name, uePropType: uPropType, typeName:typeName, propFlags: EPropertyFlagsVal(flags))

func makeFieldASUEnum*(name, typeName: string): UEField = 
  UEField(name: name, typeName:typeName, kind: uefEnumVal)

func makeUEClass*(name, parent: string, clsFlags: EClassFlags, fields: seq[UEField], metadata: seq[UEMetadata] = @[]): UEType =
  UEType(kind: uetClass, name: name, parent: parent, clsFlags: EClassFlagsVal(clsFlags), metadata:metadata, fields: fields)

func makeUEStruct*(name: string, fields: seq[UEField], superStruct = "", metadata: seq[UEMetadata] = @[], flags = STRUCT_NoFlags): UEType =
  UEType(kind: uetStruct, name: name, fields: fields, superStruct: superStruct, metadata: metadata, structFlags: flags)

func makeUEMulDelegate*(name: string, fields: seq[UEField]): UEType =
  UEType(kind: uetDelegate, delKind: uedelMulticastDynScriptDelegate, name: name, fields: fields)

func makeUEEnum*(name: string, fields: seq[UEField], metadata: seq[UEMetadata] = @[]): UEType =
  UEType(kind: uetEnum, name: name, fields: fields, metadata: metadata)

func makeUEModule*(name: string, types: seq[UEType], rules: seq[UEImportRule] = @[], dependencies: seq[string] = @[]): UEModule =
  UEModule(name: name, types: types, dependencies: dependencies, rules: rules)



func isReturnParam*(field:UEField) : bool = (CPF_ReturnParm in field.propFlags)
func isOutParam*(field:UEField) : bool = (CPF_OutParm in field.propFlags) and not field.isReturnParam()
func isRefParam*(field:UEField) : bool = (CPF_ReferenceParm in field.propFlags)
func isConstParam*(field:UEField) : bool = (CPF_ConstParm in field.propFlags)
func isConstRefParam*(field:UEField) : bool = field.isConstParam() and field.isRefParam()

