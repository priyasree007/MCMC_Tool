/**
 * ParameterDetails
 */	
public class ParameterDetails {

	String parameterName;
	double upperBound;
	double lowerBound;
	double stepSize;
	
	ParameterDetails(String parameterName, double upperBound, double lowerBound, double stepSize) {
		this.parameterName = parameterName;
		this.upperBound = upperBound;
		this.lowerBound = lowerBound;
		this.stepSize = stepSize;
	}
	
	public String getParameterName() {
		return this.parameterName;
	}
	
	public double getUpperBound() {
		return this.upperBound;
	}
	
	public double getLowerBound() {
		return this.lowerBound;
	}
	
	public double getStepSize() {
		return this.stepSize;
	}
	
	public String toString() {
		String str = "parameter name = " + this.parameterName + ", upper bound = " + this.upperBound + ", lower bound = " + this.lowerBound + ", step size = " + this.stepSize;
		return str;
	}
}
