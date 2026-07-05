import pcbnew
import sys
import os

def generate_board():
    print("Initializing KiCad board generation (110mm x 90mm)...")
    board = pcbnew.BOARD()

    # Define board dimensions: 110mm x 90mm
    width = 110.0
    height = 90.0
    margin = 5.0

    # Draw PCB Edge Outline on the Edge.Cuts layer and F.Silkscreen layer
    edge_layer = board.GetLayerID("Edge.Cuts")
    silk_layer = board.GetLayerID("F.Silkscreen")
    
    # Coordinates in nanometers (1mm = 1,000,000 nm)
    x_min, y_min = int(margin * 1000000), int(margin * 1000000)
    x_max, y_max = int((width + margin) * 1000000), int((height + margin) * 1000000)

    corners = [
        pcbnew.VECTOR2I(x_min, y_min),
        pcbnew.VECTOR2I(x_max, y_min),
        pcbnew.VECTOR2I(x_max, y_max),
        pcbnew.VECTOR2I(x_min, y_max)
    ]

    # Draw boundary outlines on both layers for maximum visibility in PDF
    for layer in [edge_layer, silk_layer]:
        for i in range(4):
            p1 = corners[i]
            p2 = corners[(i + 1) % 4]
            seg = pcbnew.PCB_SHAPE(board)
            seg.SetShape(pcbnew.SHAPE_T_SEGMENT)
            seg.SetStart(p1)
            seg.SetEnd(p2)
            seg.SetLayer(layer)
            seg.SetWidth(int(0.5 * 1000000)) # 0.5mm thick line
            board.Add(seg)

    print("PCB Edge Outline drawn successfully on Edge.Cuts and F.Silkscreen!")

    # Dict to keep track of placed footprints for net connection
    placed_footprints = {}

    # Helper function to place footprints from standard library path
    def place_component(reference, value, lib_name, footprint_name, x_mm, y_mm, rotation_deg=0):
        lib_path = f"/Applications/KiCad/KiCad.app/Contents/SharedSupport/footprints/{lib_name}.pretty"
        
        # Load footprint
        fp = pcbnew.FootprintLoad(lib_path, footprint_name)
        if not fp:
            print(f"Error: Could not load footprint {footprint_name} from {lib_path}")
            sys.exit(1)
            
        fp.SetReference(reference)
        fp.SetValue(value)
        
        # Position (convert mm to nanometers)
        pos = pcbnew.VECTOR2I(int(x_mm * 1000000), int(y_mm * 1000000))
        fp.SetPosition(pos)
        
        if rotation_deg != 0:
            fp.SetOrientation(pcbnew.EDA_ANGLE(rotation_deg, pcbnew.DEGREES_T))
            
        board.Add(fp)
        placed_footprints[reference] = fp
        print(f"Placed {reference} ({value}) at X={x_mm}mm, Y={y_mm}mm")

    # --- Place Components (Roomy & Safe Layout) ---
    # 1. Tang Console Host Sockets (2x20 Pin Headers spaced 20mm apart)
    place_component("JP1", "Tang_2x20_H1", "Connector_PinHeader_2.54mm", "PinHeader_2x20_P2.54mm_Vertical", 55.0, 40.0)
    place_component("JP2", "Tang_2x20_H2", "Connector_PinHeader_2.54mm", "PinHeader_2x20_P2.54mm_Vertical", 55.0, 60.0)

    # 2. MCR Top Connectors (Controls, Coin, Video, Power)
    place_component("J2", "MCR_P1_Controls", "Connector_PinHeader_2.54mm", "PinHeader_1x15_P2.54mm_Vertical", 25.0, 12.0)
    place_component("J3", "MCR_System_Coin", "Connector_PinHeader_2.54mm", "PinHeader_1x05_P2.54mm_Vertical", 55.0, 12.0)
    place_component("J_VID", "MCR_Video_Out", "Connector_PinHeader_2.54mm", "PinHeader_1x09_P2.54mm_Vertical", 80.0, 12.0)
    place_component("P_IN", "Power_+12V_GND", "Connector_PinHeader_2.54mm", "PinHeader_1x02_P2.54mm_Vertical", 105.0, 12.0)

    # 3. MCR Bottom Connectors (P2 Controls, Spinners)
    place_component("J5", "MCR_P2_Controls", "Connector_PinHeader_2.54mm", "PinHeader_1x19_P2.54mm_Vertical", 30.0, 88.0)
    place_component("J4", "MCR_Opt_X_Dial", "Connector_PinHeader_2.54mm", "PinHeader_1x10_P2.54mm_Vertical", 75.0, 88.0)
    
    # 4. DIP Switch Blocks (Vertical orientation = 0 deg, stacked North/South)
    place_component("SW1", "Game_Selector", "Button_Switch_THT", "SW_DIP_SPSTx08_Slide_9.78x22.5mm_W7.62mm_P2.54mm", 100.0, 42.0)
    place_component("SW2", "Cabinet_Options", "Button_Switch_THT", "SW_DIP_SPSTx08_Slide_9.78x22.5mm_W7.62mm_P2.54mm", 100.0, 68.0)

    # 5. Added Safety and Logic Hardware
    place_component("U1", "Buck_Regulator", "Package_TO_SOT_THT", "TO-220-3_Vertical", 108.0, 28.0)
    place_component("U2", "Optocoupler_P1", "Package_DIP", "DIP-16_W7.62mm", 12.0, 40.0)
    place_component("U3", "Optocoupler_Sys", "Package_DIP", "DIP-16_W7.62mm", 12.0, 65.0)
    place_component("U4", "Sync_Buffer", "Package_DIP", "DIP-20_W7.62mm", 82.0, 32.0)
    place_component("U5", "Audio_Amplifier", "Package_DIP", "DIP-8_W7.62mm", 108.0, 83.0)

    # 6. R2R Video DAC Resistors
    # Red DAC
    place_component("R1", "3.9k_Red_LSB", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", 38.0, 25.0)
    place_component("R2", "2.0k_Red_Mid", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", 38.0, 28.0)
    place_component("R3", "1.0k_Red_MSB", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", 38.0, 31.0)
    # Green DAC
    place_component("R4", "3.9k_Green_LSB", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", 48.0, 25.0)
    place_component("R5", "2.0k_Green_Mid", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", 48.0, 28.0)
    place_component("R6", "1.0k_Green_MSB", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", 48.0, 31.0)
    # Blue DAC
    place_component("R7", "3.9k_Blue_LSB", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", 58.0, 25.0)
    place_component("R8", "2.0k_Blue_Mid", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", 58.0, 28.0)
    place_component("R9", "1.0k_Blue_MSB", "Resistor_THT", "R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal", 58.0, 31.0)

    # --- Draw Electrical Wires (Ratsnest Connectivity) ---
    print("Defining and routing electrical nets...")
    
    # Net connections mapping: (NetName, Component1Ref, Pad1Number, Component2Ref, Pad2Number)
    connections = [
        # Optocoupler Isolated Inputs mapping:
        ("CAB_BTN_LEFT",    "J2", "1",   "U2", "1"),
        ("GND",             "U2", "2",   "P_IN", "2"),
        ("BTN_LEFT",        "U2", "16",  "JP1", "1"),
        ("GND",             "U2", "15",  "P_IN", "2"),
        
        ("CAB_BTN_RIGHT",   "J2", "2",   "U2", "3"),
        ("GND",             "U2", "4",   "P_IN", "2"),
        ("BTN_RIGHT",       "U2", "14",  "JP1", "2"),
        ("GND",             "U2", "13",  "P_IN", "2"),

        ("CAB_BTN_FIRE",    "J2", "5",   "U2", "5"),
        ("GND",             "U2", "6",   "P_IN", "2"),
        ("BTN_FIRE",        "U2", "12",  "JP1", "3"),
        ("GND",             "U2", "11",  "P_IN", "2"),

        ("CAB_BTN_SHIELD",  "J2", "6",   "U2", "7"),
        ("GND",             "U2", "8",   "P_IN", "2"),
        ("BTN_SHIELD",      "U2", "10",  "JP1", "4"),
        ("GND",             "U2", "9",   "P_IN", "2"),

        # R2R Video DAC - Input from FPGA Header to Pad 1 of Resistors
        ("FPGA_R0",         "JP1", "9",   "R1", "1"),
        ("FPGA_R1",         "JP1", "10",  "R2", "1"),
        ("FPGA_R2",         "JP1", "11",  "R3", "1"),

        ("FPGA_G0",         "JP1", "12",  "R4", "1"),
        ("FPGA_G1",         "JP1", "13",  "R5", "1"),
        ("FPGA_G2",         "JP1", "14",  "R6", "1"),

        ("FPGA_B0",         "JP1", "15",  "R7", "1"),
        ("FPGA_B1",         "JP1", "16",  "R8", "1"),
        ("FPGA_B2",         "JP1", "17",  "R9", "1"),

        # R2R Video DAC - Output from Pad 2 of Resistors combined into Analog color outputs to J_VID
        ("CAB_RED",         "R1", "2",    "J_VID", "1"),
        ("CAB_RED",         "R2", "2",    "J_VID", "1"),
        ("CAB_RED",         "R3", "2",    "J_VID", "1"),

        ("CAB_GREEN",       "R4", "2",    "J_VID", "3"),
        ("CAB_GREEN",       "R5", "2",    "J_VID", "3"),
        ("CAB_GREEN",       "R6", "2",    "J_VID", "3"),

        ("CAB_BLUE",        "R7", "2",    "J_VID", "5"),
        ("CAB_BLUE",        "R8", "2",    "J_VID", "5"),
        ("CAB_BLUE",        "R9", "2",    "J_VID", "5"),

        # Video sync buffer connections (74HCT244)
        ("FPGA_HSYNC",      "JP1", "18", "U4", "2"),
        ("CAB_HSYNC",       "U4", "18",  "J_VID", "8"),
        ("FPGA_VSYNC",      "JP1", "19", "U4", "4"),
        ("CAB_VSYNC",       "U4", "16",  "J_VID", "9"),

        # Power lines
        ("12V_POWER",       "P_IN", "1",  "U1", "1"),
        ("5V_REGULATED",    "U1", "3",   "JP1", "40"),
        ("GND",             "U1", "2",   "P_IN", "2"),

        # SW1 Game Selector DIPs
        ("GAME_SEL0",   "JP1", "23", "SW1", "1"),
        ("GAME_SEL1",   "JP1", "24", "SW1", "2"),
        ("GAME_SEL2",   "JP1", "25", "SW1", "3"),
        ("GAME_SEL3",   "JP1", "26", "SW1", "4"),
        ("GAME_SEL4",   "JP1", "27", "SW1", "5"),
        ("GAME_SEL5",   "JP1", "28", "SW1", "6"),
        ("GAME_SEL6",   "JP1", "29", "SW1", "7"),
        ("GAME_SEL7",   "JP1", "30", "SW1", "8"),

        # SW2 Game Options DIPs
        ("GAME_OPT0",   "JP1", "31", "SW2", "1"),
        ("GAME_OPT1",   "JP1", "32", "SW2", "2"),
        ("GAME_OPT2",   "JP1", "33", "SW2", "3"),
        ("GAME_OPT3",   "JP1", "34", "SW2", "4"),
        ("GAME_OPT4",   "JP1", "35", "SW2", "5"),
        ("GAME_OPT5",   "JP1", "36", "SW2", "6"),
        ("GAME_OPT6",   "JP1", "37", "SW2", "7"),
        ("GAME_OPT7",   "JP1", "38", "SW2", "8"),
        
        # Ground signals
        ("GND",         "J2", "13",  "P_IN", "2"),
        ("GND",         "J4", "10",  "P_IN", "2"),
        ("GND",         "J_VID", "2", "P_IN", "2"),
        ("GND",         "J_VID", "4", "P_IN", "2"),
        ("GND",         "J_VID", "6", "P_IN", "2"),
        ("GND",         "U4", "10",  "P_IN", "2"),
        ("GND",         "U5", "4",   "P_IN", "2"),
    ]

    for net_name, ref1, pad1, ref2, pad2 in connections:
        # Resolve or create the net
        net = board.FindNet(net_name)
        if not net:
            net = pcbnew.NETINFO_ITEM(board, net_name)
            board.Add(net)
            
        # Connect Pad 1
        fp1 = placed_footprints.get(ref1)
        if fp1:
            p_obj1 = fp1.FindPadByNumber(pad1)
            if p_obj1:
                p_obj1.SetNet(net)
                
        # Connect Pad 2
        fp2 = placed_footprints.get(ref2)
        if fp2:
            p_obj2 = fp2.FindPadByNumber(pad2)
            if p_obj2:
                p_obj2.SetNet(net)

    # Save board to file
    output_filename = "mcr_shield.kicad_pcb"
    pcbnew.SaveBoard(output_filename, board)
    print(f"KiCad board saved successfully as: {os.path.abspath(output_filename)}")

if __name__ == "__main__":
    generate_board()
