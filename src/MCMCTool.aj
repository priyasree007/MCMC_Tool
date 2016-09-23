import java.lang.reflect.*;
import java.io.*;
import java.util.*;
import java.awt.*;
import java.awt.event.*;
import java.awt.Dimension;
import javax.swing.*;
import javax.swing.border.TitledBorder;
import com.anylogic.engine.*;
import com.anylogic.engine.Agent;

public aspect MCMCTool
{	
	//Fields for accessing Anylogic parameters and methods
	String packageName;
	static Agent mainObject;
	static Class mainClass;
	static Field MCMCParameter;
	Method logPosterior;
	Method[] mainMethods;

	//Fields for drawing Swing frame
	JFrame jFrame;
	JPanel mainPanel, instructionPanel, responsePanel, mcmcComponentPanel;
	JLabel welcomeLabel, instructionLabel, responseLabel, mcmcComponentLabel, jLabel;
	JTextField jTextField;
	JComboBox burningPeriodList;
	JButton submitButton;
	GridBagConstraints gridConstraints;
	Font welcomeFont, instructionFont, messageFont, borderTitleFont;
	TitledBorder mcmcComponentBorder;
	boolean enableTool = true;
	
	//Fields for MCMC functionality
	int completedIterations = 0, numberOfIterationsToFindInitialTheta = 0, burningTime = 0, numberOfAccepts;
	double logPosteriorInitialTheta = Double.NEGATIVE_INFINITY, logPosteriorOldTheta, logPosteriorNewTheta;
	boolean entry = true, initialThetaFound = false;
	PrintWriter outFileSimulations, outFileResults;
	Random rand = new Random();
	ArrayList<Double> initialTheta, oldTheta, newTheta;
	ArrayList<String> parameters = new ArrayList<String>();
	ArrayList<ParameterDetails> parameterDetailsList = new ArrayList<ParameterDetails>();
	ArrayList<ArrayList<Double>> history = new ArrayList<ArrayList<Double>>();
	
	//Pointcuts
	
	pointcut initialSetUpUI(java.awt.Container container): 
		execution(* *.setup(..)) && 
		args(container); 
	
	pointcut setParameter(final Agent self, int index, boolean callOnChangeActions): 
		execution(* *.setupRootParameters(..)) && 
		args(self, index, callOnChangeActions);
	
	pointcut afterEachIteration(): 
		execution(* *.onAfterIteration(..));
	
	pointcut experimentCompleted(): 
		execution(* *ExperimentRunFast.stop(..));
	
	
	after(java.awt.Container container): initialSetUpUI(container)
	{
		//User Confirmation Window
		JDialog.setDefaultLookAndFeelDecorated(true);
		int response = JOptionPane.showConfirmDialog(null, "Do you want to use the MCMC tool?", "Enable/Disable the MCMC tool",
		JOptionPane.YES_NO_OPTION, JOptionPane.QUESTION_MESSAGE);
		if (response == JOptionPane.NO_OPTION) {
			enableTool = false;
			System.out.println("'NO' button clicked, hence MCMC tool is NOT enabld");
		} else if (response == JOptionPane.YES_OPTION) {
			System.out.println("'YES' button clicked, hence MCMC tool is enabld");
		} else if (response == JOptionPane.CLOSED_OPTION) {
			System.out.println("JOptionPane closed, hence MCMC is enabld by default");
		}
		
		if (enableTool)
		{
			packageName = thisJoinPoint.getThis().getClass().getPackage().getName();
			String ClassName = (packageName + ".Main");
			try {
				outFileSimulations = new PrintWriter(packageName + "_Output_SimulationDataset.csv");
				outFileResults = new PrintWriter(packageName + "_Output_FinalResults.csv");
				//Get the main class
				mainClass = Class.forName(ClassName);
	
				//Get the parameters of the main class
				mainMethods = mainClass.getMethods();
				String findString = "_DefaultValue_xjal";
				for (int i = 0; i < mainMethods.length; i++) {
					String searchMethod = mainMethods[i].getName().toString();
					if (searchMethod.contains(findString)) {
						String name = searchMethod.replaceAll(findString, "");
						name = name.substring(1, name.length());
						parameters.add(name);
					}
				}
			} catch (Exception e) {
				e.printStackTrace();
			}
			//Printing the parameters done	
	
			//UI frame
			jFrame = new JFrame();
			jFrame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
			jFrame.setTitle("User inputs for MCMC enabled " + packageName);
			int frameWidth = 1250;
			int frameHeight = 550;
			Dimension screenSize = Toolkit.getDefaultToolkit().getScreenSize();
			jFrame.setBounds((int) screenSize.getWidth() - frameWidth, 0, frameWidth, frameHeight);
			jFrame.setVisible(true);
	
			mainPanel = new JPanel();
			mainPanel.setLayout(new GridBagLayout());
	
			gridConstraints = new GridBagConstraints();
			gridConstraints.gridx = 1;
			gridConstraints.gridy = 1;
			gridConstraints.gridwidth = 1;
			gridConstraints.gridheight = 1;
			gridConstraints.weightx = 50;
			gridConstraints.weighty = 50;
			gridConstraints.insets = new Insets(5, 5, 5, 5);
			gridConstraints.anchor = GridBagConstraints.WEST;
			gridConstraints.fill = GridBagConstraints.BOTH;
	
			instructionPanel = new JPanel();
			instructionPanel.setLayout(new BoxLayout(instructionPanel, BoxLayout.Y_AXIS));
	
			/*paramBorder = BorderFactory.createTitledBorder("Choose Parameter for MCMC");	
			paramBorder.setTitleFont(borderTitleFont);
			parameterPanel.setBorder(paramBorder);*/
	
			mcmcComponentPanel = new JPanel();	
			mcmcComponentPanel.setLayout(new GridBagLayout());
	
			mcmcComponentBorder = BorderFactory.createTitledBorder("MCMC components");	
			mcmcComponentBorder.setTitleFont(borderTitleFont);
			mcmcComponentPanel.setBorder(mcmcComponentBorder);
	
			welcomeFont = new Font("Helvetica", Font.BOLD, 16);
			instructionFont = new Font("Helvetica", Font.ITALIC, 13);
			messageFont = new Font("Helvetica", Font.BOLD, 13);
			borderTitleFont = new Font("Helvetica", Font.BOLD, 12);
	
			welcomeLabel = new JLabel("Welcome to MCMC enabled System Dynamics Model \n", JLabel.CENTER);
			welcomeLabel.setFont(welcomeFont);
			gridConstraints.gridy = 1;
			mainPanel.add(welcomeLabel, gridConstraints);
	
			instructionLabel = new JLabel("Please ensure that you have the following defined in your model : \n", JLabel.LEFT);
			instructionLabel.setFont(messageFont);
			instructionPanel.add(instructionLabel);
	
			instructionLabel = new JLabel("1. Log prior in function called 'logPrior' \n", JLabel.LEFT);
			instructionLabel.setFont(instructionFont);
			instructionPanel.add(instructionLabel);
	
			instructionLabel = new JLabel("2. Log likelihood in function called 'logLikelihood' \n", JLabel.LEFT);
			instructionLabel.setFont(instructionFont);
			instructionPanel.add(instructionLabel);
			
			instructionLabel = new JLabel("3. Log posterior in function called 'logPosterior' \n", JLabel.LEFT);
			instructionLabel.setFont(instructionFont);
			instructionPanel.add(instructionLabel);
	
			gridConstraints.gridy = 3;
			mainPanel.add(instructionPanel, gridConstraints);
	
			responseLabel = new JLabel("Please select and input the details for the parameters on which to run MCMC : \n", JLabel.LEFT);
			responseLabel.setFont(messageFont);
			gridConstraints.gridy = 5;
			mainPanel.add(responseLabel, gridConstraints);
			
			responsePanel = new JPanel();	
			responsePanel.setLayout(new GridBagLayout());
	
			int i = 2;
			int maxLengthParameters = maxLength(parameters);
			for (String p : parameters) {
				gridConstraints.gridy = 5 + i;
				
				gridConstraints.gridx = 1;
				responsePanel.add(new JCheckBox(p), gridConstraints);
				
				gridConstraints.gridx += maxLengthParameters;
				jLabel = new JLabel("Upper Bound", JLabel.LEFT);
				responsePanel.add(jLabel, gridConstraints);
				
				gridConstraints.gridx += 10;
				jTextField = new JTextField("", 9);
				responsePanel.add(jTextField, gridConstraints);
				
				gridConstraints.gridx += 10;
				jLabel = new JLabel("Lower Bound", JLabel.LEFT);
				responsePanel.add(jLabel, gridConstraints);
				
				gridConstraints.gridx += 10;
				jTextField = new JTextField("", 9);
				responsePanel.add(jTextField, gridConstraints);
				
				gridConstraints.gridx += 10;
				jLabel = new JLabel("Step Size", JLabel.LEFT);
				responsePanel.add(jLabel, gridConstraints);
				
				gridConstraints.gridx += 10;
				jTextField = new JTextField("", 9);
				responsePanel.add(jTextField, gridConstraints);
				
				i += 2;
			}
			
			gridConstraints.gridx = 1;
			gridConstraints.gridy = 7;
			mainPanel.add(responsePanel, gridConstraints);
	
			mcmcComponentLabel = new JLabel("Burning Period : ");
			gridConstraints.gridx = 1;
			gridConstraints.gridy = 2;
			mcmcComponentPanel.add(mcmcComponentLabel, gridConstraints);
	
			Integer[] numBurningPeriod = {0, 10, 20, 100, 200, 1000, 2000, 10000, 20000};
			burningPeriodList = new JComboBox(numBurningPeriod);
			ListenForComboBox lBurningPeriodCB = new ListenForComboBox();			
			burningPeriodList.addItemListener(lBurningPeriodCB);
			gridConstraints.gridx = 2;
			gridConstraints.gridy = 2;
			mcmcComponentPanel.add(burningPeriodList, gridConstraints);	
	
			gridConstraints.gridx = 1;
			gridConstraints.gridy = i + 11;
			mainPanel.add(mcmcComponentPanel, gridConstraints);	
	
			submitButton = new JButton("Submit");	
			ListenForButton lsubmitButton = new ListenForButton();	
			submitButton.addActionListener(lsubmitButton);	
	
			gridConstraints.gridy = i + 13;
			gridConstraints.anchor = GridBagConstraints.CENTER;
			gridConstraints.fill = GridBagConstraints.NONE;
			mainPanel.add(submitButton, gridConstraints);
	
			jFrame.add(mainPanel);
			jFrame.pack();
		}
	}

	ParameterDetails parameterDetails;
	String parName;
	double upBound, lowBound, sSize;

	private class ListenForButton implements ActionListener{
		@Override
		public void actionPerformed(ActionEvent e) {
			if (e.getSource() == submitButton) {
				entry = true;
				for (int i = 0; i < parameters.size(); i++) {
					Component checkBox = ((JPanel) mainPanel.getComponent(3)).getComponent(7 * i);
					assert(checkBox instanceof JCheckBox);
					if (checkBox instanceof JCheckBox) {
						JCheckBox jCheckBox = (JCheckBox) checkBox;
						if (jCheckBox.isSelected()) {
							parName = jCheckBox.getText();
							try {
								upBound = Double.parseDouble(((JTextField) (((JPanel) mainPanel.getComponent(3)).getComponent(7 * i + 2))).getText());
								lowBound = Double.parseDouble(((JTextField) (((JPanel) mainPanel.getComponent(3)).getComponent(7 * i + 4))).getText());
								sSize = Double.parseDouble(((JTextField) (((JPanel) mainPanel.getComponent(3)).getComponent(7 * i + 6))).getText());
							} catch (NumberFormatException exception) {
								entry = false;
								JOptionPane.showMessageDialog(jFrame, "Please enter numbers in the appropriate fields", " Error : ", JOptionPane.ERROR_MESSAGE);
							}
							parameterDetails = new ParameterDetails(parName, upBound, lowBound, sSize);
							parameterDetailsList.add(parameterDetails);
							System.out.println("SELECTED PARAMETER : " + parameterDetailsList.get(parameterDetailsList.size() - 1)); //Testing
						}
					}
				}
				if (parameterDetailsList.size() == 0) {
					entry = false;
					JOptionPane.showMessageDialog(jFrame, "Please select a parameter ", " Error : ", JOptionPane.ERROR_MESSAGE);
				}
				if (entry == true) {
					jFrame.setVisible(false);
				}	
			}
		}	
	}

	class ListenForComboBox implements ItemListener{
		@Override
		public void itemStateChanged(ItemEvent e) {
			if (e.getSource() == burningPeriodList) {
				if (e.getStateChange() == ItemEvent.SELECTED) {
					Object item = e.getItem();
					burningTime = (int) item;
				}
			}
		}       
	}


	after(final Agent self, int index, boolean callOnChangeActions): setParameter(self, index, callOnChangeActions)
	{	
		if (enableTool)
		{
			mainObject = self;
			try {
				if (logPosteriorInitialTheta == Double.NEGATIVE_INFINITY) {
					initialTheta = generateInitialTheta();
					for (int i = 0; i < parameterDetailsList.size(); i++) {
						String parameterName = parameterDetailsList.get(i).getParameterName();
						MCMCParameter = mainClass.getDeclaredField(parameterName);
						MCMCParameter.set(self, initialTheta.get(i));
					}
				}
				else {
					newTheta = generatePerturbed(oldTheta);
					for (int i = 0; i < parameterDetailsList.size(); i++) {
						String parameterName = parameterDetailsList.get(i).getParameterName();
						MCMCParameter = mainClass.getDeclaredField(parameterName);
						MCMCParameter.set(self, newTheta.get(i));
					}
				}
			}
			catch (Exception e) {
				e.printStackTrace();
			}
		}
	}

	after(): afterEachIteration()
	{
		if (enableTool)
		{
			try {
				logPosterior = mainClass.getDeclaredMethod("logPosterior");
				if (initialThetaFound) {
					logPosteriorNewTheta = (double) logPosterior.invoke(mainObject);
					//System.out.println("Log Posterior : " + logPosteriorNewTheta);
	
					double unif = rand.nextDouble();
					if (logPosteriorNewTheta == Double.NEGATIVE_INFINITY && logPosteriorOldTheta == Double.NEGATIVE_INFINITY) {
						if (unif <= 0.5) {
							oldTheta = newTheta;
							logPosteriorOldTheta = logPosteriorNewTheta;
							numberOfAccepts++;
						}
					}
					else {
						if (Math.log(unif) <= Math.min(0, logPosteriorNewTheta - logPosteriorOldTheta)) {
							oldTheta = newTheta;
							logPosteriorOldTheta = logPosteriorNewTheta;
							numberOfAccepts++;
						}
					}
					
					completedIterations++;
					//System.out.println("Number of iterations completed : " + completedIterations);
					if (burningTime < completedIterations) {
						history.add(oldTheta);
						writeToFile(outFileSimulations, oldTheta);	
					}
				}
	
				else {
					logPosteriorInitialTheta = (double) logPosterior.invoke(mainObject);
					//System.out.println("Log Posterior : " + logPosteriorInitialTheta);
	
					if (logPosteriorInitialTheta != Double.NEGATIVE_INFINITY) {
						initialThetaFound = true;
						System.out.println("****** Number of iterations to find initial parameter values : " + numberOfIterationsToFindInitialTheta);
						logPosteriorOldTheta = logPosteriorInitialTheta;
						oldTheta = initialTheta;
						numberOfAccepts = 1;
						
						int i;
						String parameterNames = "";
						for (i = 0; i < parameterDetailsList.size() - 1; i++) {
							parameterNames += parameterDetailsList.get(i).getParameterName();
							parameterNames += ",";
						}
						parameterNames += parameterDetailsList.get(i).getParameterName();
						outFileSimulations.println(parameterNames);
						parameterNames = "Parameter Name,Average Value,Standard Deviation,Lower CI,Upper CI\n";
						outFileResults.println(parameterNames);
					}
				}	
			} catch (Exception e) {
				e.printStackTrace();
			}
		}
	}
	
	after(): experimentCompleted()
	{	
		if (enableTool)
		{
			try {
				System.out.println("\nNumber of new candidates accepted : " + numberOfAccepts + ", Number of iterations completed : " + completedIterations + 
						", Burning Period : " + burningTime);
				double acceptanceRate = (double) (numberOfAccepts) / (completedIterations - burningTime) * 100;
				if (burningTime < completedIterations)
					System.out.println("Acceptance Rate : " + String.format("%.2f", acceptanceRate) + "%\n");
				else
					System.out.println("Burning time is more than or equal to the number of iterations completed.\n");
				
				System.out.println("FINAL RESULTS : ");
				for (int i = 0; i < parameterDetailsList.size() ; i++) {
					double mu = 0.0, sigma = 0.0, upCI, lowCI;
					for (int j = 0; j < history.size(); j++)
						mu += history.get(j).get(i) / history.size();
					for (int j = 0; j < history.size(); j++) {
						if (history.size() != 1)
							sigma += Math.pow(history.get(j).get(i) - mu, 2) / (history.size() - 1);
					}
					sigma = Math.sqrt(sigma);
					upCI = mu + 1.96 * sigma;
					lowCI = mu - 1.96 * sigma;
					System.out.println(parameterDetailsList.get(i).getParameterName() + " :");
					System.out.println("Mean value : " + String.format("%.2f", mu));
					System.out.println("Standard deviation : " + String.format("%.2f", sigma));
					System.out.println("95% Credibility Interval : [" + String.format("%.2f", lowCI) + ", " + String.format("%.2f", upCI) +"]\n");
					outFileResults.write(parameterDetailsList.get(i).getParameterName() + ",");
					ArrayList<Double> combinedResults = new ArrayList<Double>();
					combinedResults.add(mu);
					combinedResults.add(sigma);
					combinedResults.add(lowCI);
					combinedResults.add(upCI);
					writeToFile(outFileResults, combinedResults);
				}
				outFileSimulations.close();
				outFileResults.close();
			} catch (Exception e) {
				e.printStackTrace();
			}
		}
	}
	
	
	public ArrayList<Double> generateInitialTheta()
	{
		double upBound, lowBound, parameterPerturbation;
		String parameterName;
		ArrayList<Double> initTheta = new ArrayList<Double>();
		
		try {
			for (int i = 0; i < parameterDetailsList.size(); i++) {
				upBound = parameterDetailsList.get(i).getUpperBound();
				lowBound = parameterDetailsList.get(i).getLowerBound();
				parameterPerturbation = rand.nextDouble() * (upBound - lowBound) + lowBound;
				initTheta.add(parameterPerturbation);
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
		
		numberOfIterationsToFindInitialTheta++;
		//System.out.println("Initial parameter values : " + initTheta);
		return initTheta;
	}
	
	
	public ArrayList<Double> generatePerturbed(ArrayList<Double> oldValues)
	{
		ArrayList<Double> newValues = new ArrayList<Double>();
		double upBound, lowBound, stepSize, newValue;
		
		for (int i = 0; i < oldValues.size(); i++) {
			upBound = parameterDetailsList.get(i).getUpperBound();
			lowBound = parameterDetailsList.get(i).getLowerBound();
			stepSize = parameterDetailsList.get(i).getStepSize();
			do {
				newValue = oldValues.get(i) + rand.nextGaussian() * Math.sqrt(stepSize);
			} while (newValue < lowBound || upBound < newValue);
			newValues.add(newValue);
		}
		
		//System.out.println("Current parameter values : " + newValues);
		return newValues;
	}
	
	
	public void writeToFile(PrintWriter out, ArrayList<Double> oldTheta) 
	{
		Iterator<Double> iter = oldTheta.iterator();
		while (iter.hasNext()) {
			out.print(iter.next() + ",");
		}
		out.println();
	}
	
	
	public int maxLength(ArrayList<String> list) {
        int max = 0;
        for (int i = 0; i < list.size(); i++) {
            String str = list.get(i);
            if (str.length() > max) {
                max = str.length();
            }
        }
        return max;
    }
}
