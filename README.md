 # Reverse-Pendulum-Control

# Description of Problem
Our Project is the implementation of the reverse pendulum problem on an FPGA and VGA display. This problem in 2D involves a horizontal line attempting to "balance" a vertical line. A similar example is if you attmepted to balance a rod perfectly vertical on your hand. Due to gravity the pendulum wants to fall, but the movement of the horizontal line (with some mass) alters the motion of the pendulum. 

# Background Information 

Here are the mathematical models that define the dynamics of the system. These equations can be formulated into equations representing only angular acceleration and linear acceleration. Initially, all the variables (angular and linear acceleration, velocity, position) start at zero except for the position of the angle. 
[CamScanner 12-11-2024 22.43 2.pdf](https://github.com/user-attachments/files/18105222/CamScanner.12-11-2024.22.43.2.pdf)

# Description of Design 
Initially, our VGA displays an upright pendulum with no movement at all. Our design takes an input from switches 0,1,2,3 on the FPGA to determine the initial start degree in binary (from 0 to positive 15 degrees clockwise). KEY 1 is then pressed, the degree input is loaded into the system and converted to radians within the pendulum_problem Finite State Machine, and the display is changed to reveal the pendulum at its new displaced position. KEY 2 can then be pressed to start the control, and the VGA will display the pendulum moving such that the pendulum will attempt to sit upright. 

The design uses a Finite State Machine to go through the calculations of finding new values of position, velocity, and acceleration. The Finite State Machine will also check each state to see if they are 0. Once all states are zero, the pendulum has stopped moving and has returned to the original upright position. At this point, the user can press KEY 1 again to load a new degree input into the system and repeat the process at different angle displacements. 
# Video Demo 
hopefuly 
# Conclusion 
no idea 
# Works Cited 
his VGA memory_2 module for sure, other then that idk 


