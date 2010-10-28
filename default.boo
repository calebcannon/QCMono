/*

*	All scripts must declare a "Script" class with a Main function as
	an entry point.
*	Input and output ports will be created for public variables whose
	names begin  with "input" and "output" respectively.  See the table
	for supported types.

	QC Type			Boo type
	Index 			short, ushort, int, uint, long, ulong
	Number			float, double
	Boolean			Boolean
	String			String
	Color			Not supported
	Structure		List
	Image			Not supported
	Mesh			Not supported
	Virtual			Not supported

*/

class Script:

	public inputInteger as int
	public outputInteger as int

	def Factorial(anInt as int):
		result as int = 1
		for i in range(1, anInt):
			result *= i
		return result
		
	def Main():
		 outputInteger = Factorial(inputInteger)