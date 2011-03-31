package thx.exceptions;

class InjectorException
{
	public var msg : String;
	public var infos : haxe.PosInfos;
	
	public function new( _msg : String, ?_infos : haxe.PosInfos )
	{
		msg = _msg;
		infos = _infos;
	}
}