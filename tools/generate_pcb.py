import pcbnew
import sys
import os

def generate_board():
    print("Initializing KiCad board generation...")
    board = pcbnew.BOARD()

    # Define board dimensions: 120mm x 100mm (values in micrometers -> nanometers)
    width = 120.0
    height = 100.0
    margin = 5.0

    # Draw PCB Edge Outline on the Edge.Cuts layer
    edge_layer = board.GetLayerID("Edge.Cuts")
    
    # Coordinates in nanometers (1mm = 1,000,000 nm)
    x_min, y_min = int(margin * 1000000), int(margin * 1000000)
    x_max, y_max = int((width + margin) * 1000000), int((height + margin) * 1000000)

    corners = [
        pcbnew.VECTOR2I(x_min, y_min),
        pcbnew.VECTOR2I(x_max, y_min),
        pcbnew.VECTOR2I(x_max, y_max),
        pcbnew.VECTOR2I(x_min, y_max)
    ]

    for i in range(4):
        p1 = corners[i]
        p2 = corners[(i + 1) % 4]
        seg = pcbnew.PCB_SHAPE(board)
        seg.SetShape(pcbnew.SHAPE_T_SEGMENT)
        seg.SetStart(p1)
        seg.SetEnd(p2)
        seg.SetLayer(edge_layer)
        board.Add(seg)

    print("PCB Edge Outline drawn successfully!")

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
        print(f"Placed {reference} ({value}) at X={x_mm}mm, Y={y_mm}mm")

    # --- Place Components ---
    # 1. Tang Console Host Sockets (2x20 Pin Headers spaced 50mm apart)
    place_component("JP1", "Tang_2x20_H1", "Connector_PinHeader_2.54mm", "PinHeader_2x20_P2.54mm_Vertical", 65.0, 45.0)
    place_component("JP2", "Tang_2x20_H2", "Connector_PinHeader_2.54mm", "PinHeader_2x20_P2.54mm_Vertical", 65.0, 65.0)

    # 2. MCR Top Connectors (Controls, Coin, Video, Power)
    place_component("J2", "MCR_P1_Controls", "Connector_PinHeader_2.54mm", "PinHeader_1x15_P2.54mm_Vertical", 20.0, 12.0)
    place_component("J3", "MCR_System_Coin", "Connector_PinHeader_2.54mm", "PinHeader_1x05_P2.54mm_Vertical", 55.0, 12.0)
    place_component("J_VID", "MCR_Video_Out", "Connector_PinHeader_2.54mm", "PinHeader_1x09_P2.54mm_Vertical", 85.0, 12.0)
    place_component("P_IN", "Power_+12V_GND", "Connector_PinHeader_2.54mm", "PinHeader_1x02_P2.54mm_Vertical", 115.0, 12.0)

    # 3. MCR Bottom Connectors (P2 Controls, Spinners, DIP Switches)
    place_component("J5", "MCR_P2_Controls", "Connector_PinHeader_2.54mm", "PinHeader_1x19_P2.54mm_Vertical", 25.0, 93.0)
    place_component("J4", "MCR_Opt_X_Dial", "Connector_PinHeader_2.54mm", "PinHeader_1x10_P2.54mm_Vertical", 75.0, 93.0)
    
    # 4. DIP Switch Blocks
    place_component("SW1", "Game_Selector", "Button_Switch_THT", "SW_DIP_SPSTx08_Slide_9.78x22.5mm_W7.62mm_P2.54mm", 100.0, 93.0)
    place_component("SW2", "Cabinet_Options", "Button_Switch_THT", "SW_DIP_SPSTx08_Slide_9.78x22.5mm_W7.62mm_P2.54mm", 115.0, 93.0)

    # Save board to file
    output_filename = "mcr_shield.kicad_pcb"
    pcbnew.SaveBoard(output_filename, board)
    print(f"KiCad board saved successfully as: {os.path.abspath(output_filename)}")

if __name__ == "__main__":
    generate_board()
