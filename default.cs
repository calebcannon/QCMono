/*

*	All scripts must declare a "Script" class with a Main function as
	an entry point.
*	Input and output ports will be created for public variables whose
	names begin  with "input" and "output" respectively.  See the table
	for supported types.

	QC Type			C# Type
	Index 			short, ushort, int, uint, long, ulong
	Number			float, double
	Boolean			Boolean
	String			String
	Color			Not supported
	Structure			Array
	Image			Not supported
	Mesh				Not supported
	Virtual			Not supported

*/

public class Script
{
	public int inputInteger;
	public int outputFactorial;
	
	public int factorial(int anInt)
	{
		int result = 1;
		for (int i = 2; i <= anInt; i++)
			result *= i;
		return result;
	}
	
	public void main ()
	{
		outputFactorial = factorial(inputInteger);
	}
}