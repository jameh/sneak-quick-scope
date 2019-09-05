#include <codecvt>
#include <iostream>
#include <locale>
#include <map>
#include <optional>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include <unistd.h>

typedef char32_t ch_t;
typedef std::pair<ch_t, ch_t> ch_pair;
typedef std::wstring_convert<std::codecvt_utf8<ch_t>, ch_t> converter;

//TODO for now vim default and -
inline bool block_break_char(char32_t ch) {
  bool out = !((97 <= ch && ch <= 122) || (65 <= ch && ch <= 90) ||
               (48 <= ch && ch <= 57) || ch > 255 || (192 <= ch && ch <= 255) ||
               ch == '_' || ch == '-');

  return out;
}

inline size_t get_position(size_t c, bool direction, size_t ch_bytes_size) {
  return c - (1 - direction) * (ch_bytes_size - 1);
}

void iterate_highlight_patterns(std::map<ch_pair, int> &occurences,
                                std::optional<ch_t> &last_char_op, size_t &c,
                                const ch_t &ch, size_t ch_bytes_size,
                                std::string &patt_p, std::string &patt_s,
                                size_t &hi_p, size_t &hi_s, size_t line_num,
                                std::set<ch_t> targets, bool direction,
                                bool &first_block, size_t line_offset,
                                bool disable_update_patt, bool force = false);
void iterate_highlight_patterns(std::map<ch_pair, int> &occurences,
                                std::optional<ch_t> &last_char_op, size_t &c,
                                const ch_t &ch, size_t ch_bytes_size,
                                std::string &patt_p, std::string &patt_s,
                                size_t &hi_p, size_t &hi_s, size_t line_num,
                                std::set<ch_t> targets, bool direction,
                                bool &first_block, size_t line_offset,
                                bool disable_update_patt, bool force) {

  if (last_char_op.has_value()) {
    ch_t last_char = last_char_op.value();

    if (block_break_char(ch) || force) {
      if (!disable_update_patt) {
        if (hi_p > 0) {
          std::stringstream ss;
          ss << "|%" << line_num + line_offset << "l%" << hi_p << "c";
          patt_p.append(ss.str());
        } else if (hi_s > 0) {
          std::stringstream ss;
          ss << "|%" << line_num + line_offset << "l%" << hi_s << "c";
          patt_s.append(ss.str());
        }
      }

      hi_p = 0;
      hi_s = 0;
      first_block = false;
    } else if (targets.count(ch) && targets.count(last_char)) {
      ch_pair concat = std::make_pair(last_char, ch);
      if (direction) {
        concat.swap(concat);
      }
      auto it = occurences.find(concat);
      if (it != occurences.end()) {
        it->second++;
      } else {
        occurences.insert(std::make_pair(concat, 1));
        it = occurences.find(concat);
      }
      int pair_occurances = it->second;
      if (!first_block) {
        if (pair_occurances == 1 && ((direction && !hi_p) || !direction)) {
          hi_p = get_position(c, direction, ch_bytes_size);
        } else if (pair_occurances == 2 &&
                   ((direction && !hi_p) || !direction)) {
          hi_s = get_position(c, direction, ch_bytes_size);
        }
      }
    }
  }
  last_char_op = ch;
  if (direction) {
    c += ch_bytes_size;
  } else {
    c -= ch_bytes_size;
  }
}

int main(int argc, char *argv[]) {
  if (argc != 6) {
    std::cout << "args: " << argc  << ", 6 expected" << std::endl;

    exit(1);
  }

  size_t line_num = static_cast<size_t>(std::stoi(argv[1]));
  size_t col_num = static_cast<size_t>(std::stoi(argv[2]));
  size_t line_offset = static_cast<size_t>(std::stoi(argv[3]));
  std::string keywords(argv[4]);

  std::istringstream s;
  s.str(argv[5]);
  std::vector<std::u32string> lines;
  std::wstring_convert<std::codecvt_utf8<ch_t>, ch_t> conv;

  for (std::string line; std::getline(s, line);) {
    lines.push_back(conv.from_bytes(line));
  }

  size_t c = 1;
  size_t col_idx = 0;

  if (lines.empty()) {
    return 0;
  } else if (line_num >= lines.size()) {
    line_num = lines.size() - 1;
    col_idx = lines[line_num].size() - 1;
    for (auto &ch : lines[line_num]) {
      c += conv.to_bytes(ch).size();
    }
  } else {
    while (c < col_num) {
      auto &ch = lines[line_num][col_idx];
      c += conv.to_bytes(ch).size();
      col_idx++;
    }
  }

  bool disable_on_line = true;
  size_t directional_char_limit = 4000;
  size_t directional_line_limit = static_cast<size_t>(-1);

  std::map<std::pair<ch_t, ch_t>, int> forward_occurences;
  std::map<std::pair<ch_t, ch_t>, int> backward_occurences;
  std::optional<ch_t> last_char = {};
  std::string patt_p = "";
  std::string patt_s = "";
  size_t hi_p = 0;
  size_t hi_s = 0;
  std::set<ch_t> targets = {
      'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
      'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
      'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};
  bool first_block = true;
  size_t orig_c = c;
  ch_t ch;
  size_t init_i = col_idx + 1;
  size_t ch_bytes_size;
  size_t total_ch = 0;
  for (size_t l = line_num;
       l < lines.size() && (l - line_num) <= directional_line_limit; l++) {
    last_char = {};
    for (size_t i = init_i; i < lines[l].size(); i++) {

      ch = lines[l][i];
      ch_bytes_size = conv.to_bytes(ch).size();

      iterate_highlight_patterns(forward_occurences, last_char, c, ch,
                                 ch_bytes_size, patt_p, patt_s, hi_p, hi_s, l,
                                 targets, true, first_block, line_offset,
                                 disable_on_line && l == line_num);
      total_ch++;
      if (total_ch > directional_char_limit) {
        break;
      }
    }
    if (total_ch > directional_char_limit) {
      break;
    }

    if (init_i < lines[l].size()) {
      iterate_highlight_patterns(forward_occurences, last_char, c, ch,
                                 ch_bytes_size, patt_p, patt_s, hi_p, hi_s, l,
                                 targets, true, first_block, line_offset,
                                 disable_on_line && l == line_num, true);
    }

    init_i = 0;
    c = 0;
  }

  first_block = true;
  c = orig_c;
  init_i = col_idx + 1;
  total_ch = 0;
  for (size_t l = line_num;
       l != static_cast<size_t>(-1) && (line_num - l) <= directional_line_limit;
       l--) {
    last_char = {};
    for (size_t i = init_i - 1; i != static_cast<size_t>(-1); i--) {

      ch = lines[l][i];

      ch_bytes_size = conv.to_bytes(ch).size();
      iterate_highlight_patterns(backward_occurences, last_char, c, ch,
                                 ch_bytes_size, patt_p, patt_s, hi_p, hi_s, l,
                                 targets, false, first_block, line_offset,
                                 disable_on_line && l == line_num);
      total_ch++;
      if (total_ch > directional_char_limit) {
        break;
      }
    }
    if (total_ch > directional_char_limit) {
      break;
    }

    if (init_i - 1 != static_cast<size_t>(-1)) {
      iterate_highlight_patterns(backward_occurences, last_char, c, ch,
                                 ch_bytes_size, patt_p, patt_s, hi_p, hi_s, l,
                                 targets, false, first_block, line_offset,
                                 disable_on_line && l == line_num, true);
    }
    if (l - 1 != static_cast<size_t>(-1)) {
      c = conv.to_bytes(lines[l - 1]).size();
      init_i = lines[l - 1].size();
    }
  }

  std::cout << patt_p << "\n" << patt_s << std::endl;

  return 0;
}
