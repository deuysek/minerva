package 
{
	import com.coursevector.minerva.LocaleManager;
	public function get langPack():Object
	{
		return LocaleManager.getIns().getLangPack();
	}
}