with open('lib/widgets/habit_tracker_widget.dart', 'rb') as f:
    data = f.read()
content = data.decode('utf-8')
lines = content.splitlines(keepends=True)

fire = '\U0001F525'

new_block = []
new_block.append('                                  Row(\r\n')
new_block.append('                                    children: [\r\n')
new_block.append('                                      if (streak > 0)\r\n')
new_block.append('                                        Padding(\r\n')
new_block.append('                                          padding: const EdgeInsets.only(right: 8.0),\r\n')
new_block.append('                                          child: Text(\r\n')
new_block.append('                                            "' + fire + ' $streak",\r\n')
new_block.append('                                            style: GoogleFonts.nunito(\r\n')
new_block.append('                                              fontSize: 12,\r\n')
new_block.append('                                              fontWeight: FontWeight.w600,\r\n')
new_block.append('                                              color: AppColors.orange,\r\n')
new_block.append('                                            ),\r\n')
new_block.append('                                          ),\r\n')
new_block.append('                                        ),\r\n')
new_block.append('                                      Text(\r\n')
new_block.append('                                        "Bu Hafta: $weekCompletions/7",\r\n')
new_block.append('                                        style: GoogleFonts.nunito(\r\n')
new_block.append('                                          fontSize: 12,\r\n')
new_block.append('                                          fontWeight: FontWeight.w600,\r\n')
new_block.append('                                          color: AppColors.textMid,\r\n')
new_block.append('                                        ),\r\n')
new_block.append('                                      ),\r\n')
new_block.append('                                    ],\r\n')
new_block.append('                                  ),\r\n')

# Lines 731-752 are index 730-751
print("Line 731:", repr(lines[730]))
print("Line 752:", repr(lines[751]))
lines[730:752] = new_block

new_content = ''.join(lines)
with open('lib/widgets/habit_tracker_widget.dart', 'wb') as f:
    f.write(new_content.encode('utf-8'))
print('Done, total lines:', len(lines))
