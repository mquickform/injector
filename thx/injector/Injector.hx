package thx.injector;

import thx.exceptions.InjectorException;
import haxe.rtti.CType;

typedef InjectionMap = {
	name : String,
	map : Dynamic,
	mapType : MapTypes,
}

enum MapTypes
{
	InstanceType;
	ClassType;
	SingletonType;
}

class Injector
{
	private var _mappings : Hash<InjectionMap>;
	private var _singletons : Hash<Dynamic>;
	private var _injectees : Hash<Dynamic>;
	
	public function new()
	{
		_mappings = new Hash();
		_singletons = new Hash();
		_injectees = new Hash();
	}
	
	public function mapInstance( type : Class<Dynamic>, inst : Dynamic ) : InjectionMap
	{
		var name : String = Type.getClassName( type );
		if ( _mappings == null ) _mappings = new Hash();
		if ( _mappings.exists( name ) )
			throw new InjectorException( "Instance already mapped" );
		var mapping : InjectionMap = { name : name, map : inst, mapType : InstanceType };
		_mappings.set( name, mapping );
		return mapping;
	}
	
	public function mapClass( type : Class<Dynamic>, inst : Class<Dynamic> ) : InjectionMap
	{
		var name : String = Type.getClassName( type );
		if ( _mappings == null ) _mappings = new Hash();
		if ( _mappings.exists( name ) )
			throw new InjectorException( "Class type already mapped" );
		var mapping : InjectionMap = { name : name, map : inst, mapType : ClassType };
		_mappings.set( name, mapping );
		return mapping;
	}
	
	public function mapSingleton( type : Class<Dynamic>, ?forSingleton : Class<Dynamic> ) : InjectionMap
	{
		var name : String = Type.getClassName( type );
		if ( _mappings == null ) _mappings = new Hash();
		if ( _singletons == null ) _singletons = new Hash();
		if ( _mappings.exists( name ) )
			throw new InjectorException( "Singleton already mapped" );
		var mapClass = ( forSingleton == null ) ? type : forSingleton;
		var fnd = null, inst = null, injectSingleton = false;
		var clsName = Type.getClassName( mapClass );
		if ( !_singletons.exists( clsName ) )
		{
			inst = instantiate( mapClass, true );
			_singletons.set( clsName, inst );
			injectSingleton = true;
		}
		var map = _singletons.get( clsName );
		var mapping : InjectionMap = { name : name, map : map, mapType : SingletonType };
		_mappings.set( name, mapping );
		if ( injectSingleton )
			applyInjection( inst );
		return mapping;
	}
	
	public function inject( inst : Dynamic )
	{
		applyInjection( inst );
	}
	
	private function applyInjection( inst : Dynamic, ?recursive : Bool = false )
	{
		var cls = Type.getClass( inst );
		applyInjectionToClass( inst, cls, recursive );
	}
	
	private function applyInjectionToClass( inst : Dynamic, cls : Class<Dynamic>, recursive : Bool, ?recurred : Bool = false )
	{
		if ( cls == null )
			return;
		if ( _injectees == null ) _injectees = new Hash();
		var clsName = Type.getClassName( cls );
		if ( !_injectees.exists( clsName ) )
			_injectees.set( clsName, true );
		var datas = haxe.rtti.Meta.getFields( cls );
		for ( fld in Reflect.fields( datas ) )
			if ( Reflect.hasField( Reflect.field( datas, fld ), "Inject" ) )
			{
				var rtti = untyped cls.__rtti;
				if ( rtti == null )
					return;
		        var x = Xml.parse(rtti).firstElement();
		        var infos = new haxe.rtti.XmlParser().processElement( x );
		        var iCls = Type.enumParameters( getClassFields( cls ).get( fld ).type )[0];
				if ( !_mappings.exists( iCls ) )
					throw new InjectorException( "Class type not mapped for field " + fld + " in class " + clsName );
				else
				{
					var mapping = _mappings.get( iCls );
					switch ( mapping.mapType )
					{
						case InstanceType, SingletonType:
							Reflect.setField( inst, fld, mapping.map );
						case ClassType:
							Reflect.setField( inst, fld, instantiate( mapping.map ) );
					}
				}
			}
		if ( recursive )
			applyInjectionToClass( inst, Type.getSuperClass( cls ), recursive, true );
	}
	
	public function getInstance( type : Class<Dynamic> ) : Dynamic
	{
		var cls = Type.getClassName( type );
		var obj;
		if ( _mappings.exists( cls ) )
		{
			var map = _mappings.get( cls );
			switch ( map.mapType )
			{
				case ClassType:
					throw new InjectorException( "Unable to return map instance of type Class." );
				default:
					obj = map.map;
			}
		}
		else
			throw new InjectorException( "No mapping exists for class " + cls );
		return obj;
	}
	
	public function getMap( type : Class<Dynamic> )
	{
		var cls = Type.getClassName( type );
		return hasMap( type ) ? _mappings.get( cls ) : null;
	}
	
	public function hasMap( type : Class<Dynamic> ) : Bool
	{
		var cls = Type.getClassName( type );
		return _mappings.exists( cls );
	}
	
	public function unmap( type : Class<Dynamic> )
	{
		if ( hasMap( type ) )
		{
			var cls = Type.getClassName( type );
			_mappings.remove( cls );
		}
	}
    
	public function instantiate( type : Class<Dynamic>, ?preventInjection : Bool = false ) : Dynamic
	{
		var inst = Type.createInstance( type, [] );
		if ( !preventInjection )
			applyInjection( inst, true );
		return inst;
	}
	
	/***************************
	 *     PRIVATE METHODS
	 ***************************/
	
	private function getClassFields( cls : Class<Dynamic> )
	{
		return unifyFields( getClassDef( cls ) );
	}
	
	private function unifyFields( cls : Classdef, ?h : Hash<ClassField> ) : Hash<ClassField> 
	{
		if ( h == null ) 
			h = new Hash();
		for ( f in cls.fields )
			if ( !h.exists( f.name ) )
				h.set( f.name, f );
		var parent = cls.superClass;
		if ( parent != null ) 
		{
			var c = getClassDef( Type.resolveClass( parent.path ) );
			if ( c != null )
				unifyFields( c, h );
		}
		return h;
	}
   
	private function getClassDef( cls : Class<Dynamic> )
	{
		var x = Xml.parse( untyped cls.__rtti ).firstElement();
		var infos = new haxe.rtti.XmlParser().processElement( x );
		return ( Type.enumConstructor( infos ) == "TClassdecl" ) ? Type.enumParameters( infos )[0] : null;
	}
}
